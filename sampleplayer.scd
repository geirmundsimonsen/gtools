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

g.sp = { |e, sample|
    var d = ();
    d.buf = sample.buf;
    d.rootPitch = sample.root ? 60;

    if (sample.buf.numChannels == 1) {
        d.instrument = "sp-mono";
    } {
        d.instrument = "sp-stereo";
    };

    d;
};

g.spSynth = { |e, sample, args|
    var basicArgs = g.sp(sample);
    var instrument = basicArgs.removeAt('instrument');
    Synth(instrument, (basicArgs ++ args).asPairs);
};

g.spMidi = { |e, sample, envFunc|
    var notes = 128.collect { |n| (pitch: n, sounding: false) };

    MIDIdef('note_on_sampleplayer', { |val, num, chan, src|
        notes[num].sounding = true;
        notes[num].soundingSynth = g.spSynth(sample, (pitch: num, env: envFunc.value(val / 127)));
    }, nil, nil, 'noteOn');

    MIDIdef('note_off_sampleplayer', { |val, num, chan, src|
        notes[num].sounding.if {
            notes[num].sounding = false;
            notes[num].soundingSynth.release;
        }
    }, nil, nil, 'noteOff');
};