g.createProject = { |e, savePath|
	var p = ();

	not(Server.default.serverRunning).if { "Hey, boot server!".throw };

	savePath = savePath ? ("c:/code/sc/projects/proj-"++Date.localtime.format("%Y%m%d_%H%M"++".scx"));
	p.savePath = savePath;

	p.state = this.executeFile(savePath) !? { |state|
		("Loading " ++ savePath).postln;
		g.addProtoForKnownTypesAndPrepareForUse(state);
		state;
	} ?? {
		var state = ();
		state.samples = Array.fill(128, { () });
		state;
	};
	p.simpleController = SimpleController(p.state);
	p.stateHooks = IdentityDictionary();

	128.do { |i| p.stateHooks[("sample-" ++ i).asSymbol] = IdentitySet() };
	ShutDown.add { p.save };

	p.s = { |e, index, sample|
        sample.isNil.if {
            p.state.samples[index].sample;
        } {
			p.state.samples[index].sample = sample;
			p.stateHooks[("sample-" ++ index).asSymbol].do { |id|
				p.state.changed(id);
			}
		}
    };

	p.registerChangeFunc = { |e, view, key, updateFunc|
        var randomKey = 1000000000.rand.asSymbol;
        p.stateHooks[key].add(randomKey);
        p.simpleController.put(randomKey, updateFunc);
        view.onClose = {
            p.simpleController.removeAt(randomKey);
            p.stateHooks[key].remove(randomKey);
        };
    };

	p.view = {
		var v = View(nil, Rect(40, 40, 400, 480));

		not(Server.default.serverRunning).if { "Hey, boot server!".throw };

        v.background = Color.hsv(0, 0, 0.18);

        g.sampleView(p, v, Rect(0, 0, 400, 480));
        g.commands(p, v);

		v.onClose = { p.save };

        v.front;
	};

	p.save = {
		var state = p.state.deepCopy;
		g.reduceKnownObjectsAndRemoveProto(state);
		state.writeArchive(savePath);
	};

	p;
};

g.reduceKnownObjectsAndRemoveProto = { |e, x|
	case
	{ x.class.name === 'IdentityDictionary' } {
		(x.type.notNil && ((x.type === 'sample') || (x.type === 'recording'))).if {
			x.reduceForArchiving;
			x.proto = nil;
		};
	}
	{ (x.class.name === 'Array') || (x.class.name === 'Event') || (x.class.name === 'Environment') || (x.class.name === 'IdentityDictionary') } {
		x.do { |item|
			g.reduceKnownObjectsAndRemoveProto(item);
		}
	}
};

g.addProtoForKnownTypesAndPrepareForUse = { |e, x|
	case
	{ x.class.name === 'IdentityDictionary' } {
		(x.type.notNil).if {
			switch (x.type,
				'sample', { x.proto = g.sampleProto },
				'record', { x.proto = g.recordProto }
			);
			x.prepareForUse;
		};
		
		x.do { |item|
			g.addProtoForKnownTypesAndPrepareForUse(item);
		};
	}
	{ (x.class.name === 'Array') || (x.class.name === 'Event') || (x.class.name === 'Environment') || (x.class.name === 'IdentityDictionary') } {
		x.do { |item|
			g.addProtoForKnownTypesAndPrepareForUse(item);
		}
	}
};