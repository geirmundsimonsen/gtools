{ |frameworkDir|
	g = ();

	g.load = {
		"LOADING GTOOLS".postln;

		MIDIIn.connectAll;

		this.executeFile(frameworkDir ++ "/includes.scd").do { |filename| 
			this.executeFile(frameworkDir ++ filename)
		};

		g
	};

	g.load;
};