Metronome {
    classvar buf;

    *initClass {
        StartUp.add {
            this.loadSynthDef;
            Server.default.doWhenBooted {
                this.loadSamples;
            }
        }
    }

    *loadSamples {
        buf = Buffer.read(Server.default, "C:/samples/ni/Maschine Library/Samples/Drums/Wooden/Clave ExtraPerc V2.wav");
    }

    *loadSynthDef {
        SynthDef("metronome", { |buf, amp|
            var pb = PlayBuf.ar(2, buf, BufSampleRate.ir(buf) / SampleRate.ir, doneAction: 2);
            OffsetOut.ar(0, pb * amp);
        }).add;
    }

    *args {
        var env = ();
        env.buf = buf;
        env.instrument = "metronome";
        ^env;
    }
}

SamplePlayer {
    *initClass {
        "loading SamplePlayer".postln;

        StartUp.add {
            MIDIIn.connectAll;
            this.loadSynthDefs;
        };
    }

    *loadSynthDefs {
        SynthDef("sp-mono", { |buf, pitch=60, rootPitch=60, start=0, gate=1, pan=0|
            var env = Env.newClear(4);
            var envctl = \env.ir(env.asArray);
            var pb = PlayBuf.ar(1, buf, 2**((pitch-rootPitch)/12) * (BufSampleRate.ir(buf) / SampleRate.ir), 1.0, start * BufSampleRate.ir(buf), doneAction: 2);
            var aeg = EnvGen.ar(envctl, gate, doneAction: 2);
            OffsetOut.ar(0, Pan2.ar(pb * aeg, pan));
        }).add;

        SynthDef("sp-stereo", { |buf, pitch=60, rootPitch=60, start=0, gate=1, pan=0|
            var env = Env.newClear(4);
            var envctl = \env.ir(env.asArray);
            var pb = PlayBuf.ar(2, buf, 2**((pitch-rootPitch)/12) * (BufSampleRate.ir(buf) / SampleRate.ir), 1.0, start * BufSampleRate.ir(buf), doneAction: 2);
            var aeg = EnvGen.ar(envctl, gate, doneAction: 2);
            var sig = pb * aeg;
            OffsetOut.ar(0, Pan2.ar(sig[0], pan.linlin(0, 1, -1, 1)) + Pan2.ar(sig[1], pan.linlin(-1, 0, -1, 1)));
        }).add;
    }

    *args { |sample|
        var env = ();
		env.buf = sample.buf;
		env.rootPitch = sample.root ? 60;

		if (sample.buf.numChannels == 1) {
			env.instrument = "sp-mono";
		} {
			env.instrument = "sp-stereo";
		};

		^env;
    }

    *synth { |sample, args|
        var basicArgs = this.args(sample);
        var instrument = basicArgs.removeAt('instrument');
        ^Synth(instrument, (basicArgs ++ args).asPairs);
    }

    *midi { |sample, envFunc|
        var notes = 128.collect { |n| (pitch: n, sounding: false) };

        MIDIdef('note_on_sampleplayer', { |val, num, chan, src|
            notes[num].sounding = true;
            notes[num].soundingSynth = this.synth(sample, (pitch: num, env: envFunc.value(val / 127)));
        }, nil, nil, 'noteOn');

        MIDIdef('note_off_sampleplayer', { |val, num, chan, src|
            notes[num].sounding.if {
                notes[num].sounding = false;
                notes[num].soundingSynth.release;
            }
        }, nil, nil, 'noteOff');
    }
}

Sample {
    var <>buf;
    var <>root;

    *new { |path, root|
        ^super.newCopyArgs(Buffer.read(Server.default, path), root);
    }
}

Recording {
    var <>recording;
    var <>start = 0;
    
    var startTime;
    var phase;
    var originalBeatDur;

    record {
        var phase = 1 - TempoClock.timeToNextBeat;
        var notes;
        var latency;

        startTime = TempoClock.beats; 
        recording = SortedList(function: {|a, b| a.time < b.time });
        notes = 128.collect { |n| (pitch: n, sounding: false) };
        latency = Server.default.latency * TempoClock.tempo;
        originalBeatDur = TempoClock.tempo.reciprocal;

        MIDIdef('note_on_recorder', { |val, num, chan, src|
            notes[num].sounding = true;
            notes[num].time = TempoClock.beats - startTime - latency + phase;
            notes[num].amp = val / 127;
        }, nil, nil, 'noteOn');

        MIDIdef('note_off_recorder', { |val, num, chan, src|
            notes[num].sounding.if {
                notes[num].sounding = false;
                recording.add((
                    pitch: num,
                    amp: notes[num].amp,
                    time: notes[num].time,
                    length: (TempoClock.beats - startTime - latency + phase) - notes[num].time
                ));

                (recording.size == 1).if {
                    (notes[num].time % 1 < 0.9).if {
                        start = notes[num].time.div(1);
                    } {
                        start = notes[num].time.div(1) + 1;
                    }
                };
            }
        }, nil, nil, 'noteOff');
    }

    stop {
        MIDIdef('note_on_recorder', {}, nil, nil, 'noteOn');
        MIDIdef('note_off_recorder', {}, nil, nil, 'noteOff');
    }

    play { |sample, quant, length=nil, loopCount=1, quantize=nil|
        var durseq, lengthseq, pitchseq;
        var rec = recording.deepCopy;

        quantize !? { |q| Util.quantize(rec, q.resolution, q.strength) };
	
        durseq = List();
        rec.doAdjacentPairs { |a, b| durseq.add(b.time - a.time) };
        (length == nil).if {
            durseq.add(1);
        } {
            (rec.first.time + length - rec.last.time) !? { |durToFirstEvent|
                (durToFirstEvent > 0).if {
                    durseq.add(rec.first.time + length - rec.last.time);
                } {
                    "Length is too short".throw;
                }
            }
        };
        
        lengthseq = rec.collect { |item|
            [Env([item.amp, item.amp, 0], [item.length * originalBeatDur, 0.001])];
        };
        
        pitchseq = rec.collect { |item| item.pitch };
        
        Pbind(*((dur: Pseq(durseq, loopCount), env: Pseq(lengthseq, loopCount), pitch: Pseq(pitchseq, loopCount)) ++ SamplePlayer.args(sample)).asPairs).play(quant: Quant(quant, phase: rec.first.time - start));
    }
}

Util {
    *quantize { |recording, resolution, strength|
        recording.do { |note|
            note.time = note.time.softRound(resolution, 0, strength);
        }
    }

    // Usable in a Pattern as Prout(Util.sweeper(min, max)). Use macro knob to sweep value.
	// 14-bit MIDI mode.
    *sweeper { |in, out|
		^{
			var msb = 64;
			var lsb = 0;
			var bit14 = 8192;

			MIDIdef('parameter_sweeper', { |val, num, chan, src|
				(num == 11).if {
					msb = val;
				};
				(num == 43).if {
					lsb = val;
					bit14 = (msb * 128) + lsb;
				};
			}, [11, 43], nil, 'control');

			loop {
				bit14.linlin(0, 16383, in, out).postln.yield;
			}
		}
	}
}