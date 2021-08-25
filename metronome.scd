g.metronome = IdentityDictionary(know: true);

SynthDef("metronome", { |buf, amp|
    var pb = PlayBuf.ar(2, buf, BufSampleRate.ir(buf) / SampleRate.ir, doneAction: 2);
    OffsetOut.ar(0, pb * amp);
}).add;

Server.default.doWhenBooted {
    g.metronome.buf = Buffer.read(Server.default, "C:/samples/ni/Maschine Library/Samples/Drums/Wooden/Clave ExtraPerc V2.wav");
};

g.metronome.play = { |e, quant|
    e.kill;
    e.eventStreamPlayer = Pbind(*[instrument: 'metronome', buf: g.metronome.buf]).play(quant: quant);
};

// Object.stop exists, so nil.stop also exists.
g.metronome.kill = { |e|
    e.eventStreamPlayer !? { |esp| esp.stop };
    e.eventStreamPlayer = nil;
}