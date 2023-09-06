// set batch mode to hide image processing and imporve speed
setBatchMode(true);

// set directory and load array of all files
path = getDirectory("Choose a Folder"); 
filelist = getFileList(path);

// tell ImageJ which measurements to take
run("Set Measurements...", "area mean min median display redirect=None decimal=0");

// set up your batch loop
for (i=0; i< filelist.length; i++) {
	// process _O tiff files only
	if (endsWith(filelist[i], "_O.tif") || endsWith(filelist[i], "_O.tiff"))  {
		 // open each file with Bio-Formats and convert to RGB
         run("Bio-Formats Importer", "open=[" + path + filelist[i] + "] color_mode=Default rois_import=[ROI manager] view=Hyperstack stack_order=XYCZT");         
         run("RGB Color");
         selectWindow(filelist[i]);
         close();
        
        // define whitespace with a color (saturation) threshold
        run("Duplicate...", "title=Dup");
        run("HSB Stack");
		run("Convert Stack to Images");
		selectWindow("Hue");
		rename("0");
		selectWindow("Saturation");
		rename("1");
		selectWindow("Brightness");
		rename("2");
		min=newArray(3);
		max=newArray(3);
		filter=newArray(3);
		a=getTitle();
		min[0]=0;
		max[0]=255;
		filter[0]="pass";
		min[1]=0;
		max[1]=15;
		filter[1]="pass";
		min[2]=215;
		max[2]=255;
		filter[2]="pass";
		for (x=0;x<3;x++){
		  selectWindow(""+x);
		  setThreshold(min[x], max[x]);
		  run("Convert to Mask");
		  if (filter[x]=="stop")  run("Invert");
}
		imageCalculator("AND create", "0","1");
		imageCalculator("AND create", "Result of 0","2");
		for (x=0;x<3;x++){
		  selectWindow(""+x);
		  close();
}
		selectWindow("Result of 0");
		close();
		selectWindow("Result of Result of 0");
		rename(a);

		// remove whitespace from the full color image
		run("Create Selection");
		selectWindow(filelist[i] + " (RGB)");
		run("Restore Selection");
		setBackgroundColor(0, 0, 0);
		run("Clear", "slice");
		run("Select None");
		
		// name whitespace definition to call later
		selectWindow("2");
		rename("Whitespace");	

		// H&E deconvolutions from full color image
		selectWindow(filelist[i] + " (RGB)");
		run("Colour Deconvolution", "vectors=[H&E 2]");
		selectWindow(filelist[i] + " (RGB)-(Colour_1)");
		rename("Purple");
		selectWindow(filelist[i] + " (RGB)-(Colour_3)");
		rename("Green");
		selectWindow(filelist[i] + " (RGB)");
		run("Colour Deconvolution", "vectors=[H&E]");
		selectWindow(filelist[i] + " (RGB)-(Colour_1)");
		rename("Blue");	
				
		// amplify the artifacts and define tissue creases
        selectWindow("Green");
        run("Duplicate...", "title=Green1");
        run("Gaussian Blur...", "sigma=10");
		imageCalculator("Multiply create 32-bit", "Green","Green1");            		
		setThreshold(-1e30, 40000); 
		run("Create Selection");		
		run("Analyze Particles...", "size=25-Infinity show=Masks");

		// combine the whitespace and crease areas into an unwanted area mask
		selectWindow("Whitespace");		
		run("Create Selection");					
		selectWindow("Mask of Result of Green");
		run("Restore Selection");
		run("Clear", "slice");
		run("Select None");
		rename("Background");	
		
		// remove unwanted area from each colored image from deconvolutions
		run("Create Selection");			
		selectWindow(filelist[i] + " (RGB)-(Colour_2)");
		run("Restore Selection");
		run("Clear", "slice");
		run("Select None");
		
		selectWindow("Background");		
		run("Create Selection");			
		selectWindow("Purple");
		run("Restore Selection");
		run("Clear", "slice");
		run("Select None");	
			
		selectWindow("Background");		
		run("Create Selection");			
		selectWindow("Blue");
		run("Restore Selection");
		run("Clear", "slice");
		run("Select None");			
								
		// measure eosin and hematoxylin saturation
        selectWindow(filelist[i] + " (RGB)-(Colour_2)");
		setThreshold(1, 250); 
		run("Create Selection");
		run("Measure");	
		run("Select None");
		rename("Pink");		
		
		selectWindow("Purple");
		setThreshold(1, 255); 
		run("Create Selection");
		run("Measure");	
		run("Select None");
		
		selectWindow("Blue");
		setThreshold(155, 255); 
		run("Create Selection");
		run("Measure");	
		run("Select None");
		
		// determine your measurement settings from saturation
		// these equations are the result of large batch manual trial and error with various
		// saturation levels from different slides/experiments.
		// it is not perfect, but it is consistent, transparent, and pretty good.
		Pink = 0 + (6 * i);
		Purple = 1 + (6 * i);
		Blue = 2 + (6 * i);
		
		PinkMED = getResult("Median", Pink);
		PinkMEAN = getResult("Mean", Pink);
		PinkMIN = getResult("Min", Pink);
		PurpleMED = getResult("Median", Purple);
		BlueMED = getResult("Median", Blue);
		
		if (PinkMEAN >= 170) {
        	WPEosin = PinkMED + 40;
        	if (WPEosin > 255) {WPEosin = 255;}
		} else {
        	WPEosin = PinkMED + 10;
        }
		
		if (PurpleMED <= 40 && PinkMIN >= 20) {
        	WPHema = PurpleMED;
		} else if (PurpleMED <= 40) {
        	WPHema = PurpleMED + 5;
        } else {
        	WPHema = PurpleMED + 10;
        }
		
		if (PinkMED >= 190) {
        	FEa = 165;
        	FEb = 210;
        	RBC = 85;
		} else if (PinkMED >= 180) {
        	FEa = 165;
        	FEb = 210;
        	RBC = 75;
		} else {
        	FEa = 155;
        	FEb = 200;
        	RBC = 65;
        }
        
        if (BlueMED > 215) {
        	AC = 254;
		} else {
        	AC = 234;
        }
	
		// print calculated values
		print("i=" + i + " WP Eosin=" + WPEosin + " FE=" + FEa + "_" + FEb + " RBC=" + RBC + " AC=" + AC);			
														
		// define the WP from eosin
        selectWindow("Pink");	               	
		setThreshold(WPEosin, 255); 
		run("Create Selection");
		run("Analyze Particles...", "size=3000-Infinity show=Masks");
        run("Fill Holes");	
        rename("WP_Pink");	

       	// define the WP from hematoxylin
        selectWindow("Purple");	               	
		setThreshold(1, WPHema); 
		run("Create Selection");
		run("Analyze Particles...", "size=3000-Infinity show=Masks");
        run("Fill Holes");	
        rename("WP_Purple");
        
        // merge eosin and hematoxylin definitions to create final white pulp mask
		imageCalculator("Add create 32-bit", "WP_Pink","WP_Purple");
		setThreshold(256, 1e30); 
		run("Create Selection");
		run("Measure");						
		run("Create Mask");
        rename("WP");	
			
		// save white pulp mask
		selectWindow("WP");	
		analyzedName = replace(replace(filelist[i],"_O.tiff","_WP.tiff"),"_O.tif","_WP.tif");
		save(path + analyzedName);	       
		
		// subtract white pulp from the pink image
		selectWindow("WP");		
		run("Invert");	
        run("Duplicate...", "title=WP_Sub");		
        imageCalculator("Divide create 32-bit", "WP","WP_Sub"); 
        imageCalculator("Multiply create 32-bit", "Pink","Result of WP"); 		

		// define the faded eosin area   
        selectWindow("Result of Pink");
        setThreshold(FEa, FEb);
		run("Create Selection");
        run("Analyze Particles...", "size=75-Infinity show=Masks"); 
        rename("FE");               	
		run("Create Selection");        		
		run("Measure");

        // save the faded eosin mask
        selectWindow("FE");	
        analyzedName = replace(replace(filelist[i],"_O.tiff","_FE.tiff"),"_O.tif","_FE.tif");
		save(path + analyzedName); 	 
		
		// measure anuclear area (acellular area)
        selectWindow("Blue");		
		setThreshold(AC, 255, "raw");
		run("Create Selection");
        run("Analyze Particles...", "size=250-Infinity show=Masks");
        rename("AN");
        run("Create Selection");
        run("Measure");
        
	    // save acellular area mask
		selectWindow("AN");			
		analyzedName = replace(replace(filelist[i],"_O.tiff","_AN.tiff"),"_O.tif","_AN.tif");
		save(path + analyzedName);	
				        																															
		run("Close All");      

	}
}
resultName = "HE_Results_RAW.csv";
saveAs("Results", path + resultName);
run("Clear Results");

setBatchMode(false);