App {
    var <>state;
    var <>simpleController;
    var <>stateHooks;

    *new {
        ^super.newCopyArgs().init;
    }

    init {
        state = ();
        simpleController = SimpleController(state);
        stateHooks = IdentityDictionary();

        state.samples = Array.fill(128, { (sample: nil) });

        128.do { |i|
            stateHooks[("sample-" ++ i).asSymbol] = IdentitySet();
        };
    }

    s { |index, sample|
        sample.isNil.if {
            ^state.samples[index].sample;
        };

        state.samples[index].sample = sample;
        stateHooks[("sample-" ++ index).asSymbol].do { |id|
            state.changed(id);
        }
    }

    registerChangeFunc { |view, key, updateFunc|
        var randomKey = 1000000000.rand.asSymbol;
        stateHooks[key].add(randomKey);
        simpleController.put(randomKey, updateFunc);
        view.onClose = { 
            simpleController.remove(randomKey);
            stateHooks[key].remove(randomKey);
        };
    }

    gui {
        var v = View(nil, Rect(40, 40, 640, 480));
        v.background = Color.hsv(0, 0, 0.18);

        CommandView.attach(this, v, Rect(0, 0, 320, 400));
        SampleView.attach(this, v, Rect(320, 0, 320, 400));

        ^v.front;
    }
}

// colorizer.org to set text color against bg color

SampleView {
    *attach { |app, parent, bounds|
        var lineHeight = 24;
        var v = View(parent, bounds);
        v.background = Color.hsv(0, 0, 0.22);

        128.do { |i|
            StaticText(v, Rect(0, i * lineHeight, bounds.width-lineHeight, lineHeight)) !? { |st|
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
                    app.s(i, Sample(ds.value));
                    ds.value = "";
                };
            };
        }
    }
}

CommandView {
    *attach { |app, parent, bounds|
        var lineHeight = 24;
        var v = View(parent, bounds);
        v.background = Color.hsv(0, 0, 0.20);

        StaticText(v, Rect(0, 0 * lineHeight, bounds.width, lineHeight)) !? { |st|
            st.stringColor = Color.hsv(0.33, 0.5, 0.7);
            st.string = "r - record";
            st.font = Font.monospace(16);
        };

        StaticText(v, Rect(0, 1 * lineHeight, bounds.width, lineHeight)) !? { |st|
            st.stringColor = Color.hsv(0.33, 0.5, 0.7);
            st.string = "m - select instrument for MIDI";
            st.font = Font.monospace(16);
        };

        v.parents.first.keyDownAction = { |topView,c,mod|
            switch (c,
                $r, {
                    "recording started".postln;
                    v.remove;
                },
                $m, {
                    "selecting instrument".postln;
                    v.remove;
                    this.selectPlaybackInstrument(app, parent, bounds);
                }
            );
        }
    }

    *selectPlaybackInstrument { |app, parent, bounds|
        var lineHeight = 24;
        var v = View(parent, bounds);
        v.background = Color.hsv(0, 0, 0.20);

        StaticText(v, Rect(0, 0 * lineHeight, bounds.width, lineHeight)) !? { |st|
            st.stringColor = Color.hsv(0.33, 0.5, 0.7);
            st.string = "s - choose sample";
            st.font = Font.monospace(16);
        };

        v.parents.first.keyDownAction = { |topView,c,mod|
            switch (c,
                $s, {
                    v.remove;
                    this.typeIndex(app, parent, bounds, { |index|
                        index.postln;
                        app.s(index).postln;
                        (index > 128).if { 
                            "Index out of bounds.";
                        } {
                            app.s(index) !? { |sample|
                                SamplePlayer.midi(sample, { |v| Env.asr(0, v, 0.01); });
                            } ?? {
                                "No sample at index " ++ index ++ ".";
                            }
                        }
                    })
                },
            );
        }
    }

    *typeIndex { |app, parent, bounds, useIndexFunc|
        var lineHeight = 24;
        var index = "";
        var v = View(parent, bounds);
        var retMsg;
        v.background = Color.hsv(0, 0, 0.20);

        StaticText(v, Rect(0, 0 * lineHeight, bounds.width, lineHeight)) !? { |st|
            st.stringColor = Color.hsv(0.33, 0.5, 0.7);
            st.string = "Type index:";
            st.font = Font.monospace(16);
        };

        retMsg = StaticText(v, Rect(0, 1 * lineHeight, bounds.width, lineHeight)) !? { |st|
            st.stringColor = Color.hsv(0.33, 0.5, 0.7);
            st.font = Font.monospace(16);
        };

        v.parents.first.keyDownAction = { |topView,c,mod|
            ((c >= $0) && (c <= $9)).if {
                index = index ++ c;
                retMsg.string = index;
                (index.size == 3).if {
                    var retVal = useIndexFunc.value(index.asInteger);
                    (retVal.class.name === 'String').if {
                        retMsg.string = retVal;
                        index = "";
                    } {
                        v.remove;
                        this.attach(app, parent, bounds);
                    };
                }
            }
        }
    }
}