g.sampleView = { |e, app, parent, bounds|
	var lineHeight = 24;
	var v = View(parent, bounds);
	v.background = Color.hsv(0, 0, 0.22);

	128.do { |i|
		StaticText(v, Rect(0, i * lineHeight, 60, lineHeight))
		.stringColor_(Color.hsv(0.3, 0.2, 0.9))
		.font_(Font.monospace(16))
		.string_(i);

		StaticText(v, Rect(60, i * lineHeight, bounds.width-lineHeight-60, lineHeight)) !? { |st|
			st.stringColor = Color.hsv(0, 0.2, 0.9);
			st.font = Font.monospace(16);
			app.s(i) !? { |sample| st.string = PathName(sample.buf.path).fileName; };
			app.registerChangeFunc(st, ("sample-"++i).asSymbol, { |state|
				if (state.samples[i].sample == nil) {
					st.string = "";
				} {
					st.string = PathName(state.samples[i].sample.buf.path).fileName;
				};
			});
		};

		DragSink(v, Rect(bounds.width-lineHeight, i * lineHeight, lineHeight, lineHeight)) !? { |ds|
			ds.action = { |ds|
				app.s(i, g.sample(ds.value));
				ds.value = "";
			};
		};
	}
};

g.commands = { |e, app, view|
	var typeSampleIndex, selectMIDIInstrument, menu, record;

	typeSampleIndex = (info: { "Type index [nnn]:".postln; }, action: { |v, k|
		typeSampleIndex.r.next(k);
	}, routine: { Routine { |k|
		var index = "";
		loop {
			((k >= $0) && (k <= $9)).if {
				index = index ++ k;
				index.postln;
				(index.size == 3).if {
					index = index.asInteger;
					(index > 128).if
					{ "Index out of bounds.".postln;}
					{ g.spMidi(app.s(index), { |v| Env.asr(0, v, 0.01); }) };
					menu.info; view.keyDownAction = menu['action'];
				}
			};
			k = "".yield;
		}
	}});

	selectMIDIInstrument = (info: { "s - choose sample".postln; }, action: { |v, k|
		switch (k,
			$s, { typeSampleIndex.info; view.keyDownAction = typeSampleIndex['action']; typeSampleIndex.r = typeSampleIndex.routine }
		)
	});

	menu = (info: { "r - record\nm - select MIDI instrument".postln; }, action: { |v, k|
		switch (k,
			$r, { record.info; view.keyDownAction = record['action'] },
			$m, { selectMIDIInstrument.info; view.keyDownAction = selectMIDIInstrument['action']; }
		)
	});

	menu.info;
	view.keyDownAction = menu['action'];
}