g.quantize = { |e, recording, resolution, strength|
    recording.do { |note|
        note.time = note.time.softRound(resolution, 0, strength);
    }
};

// Usable in a Pattern as Prout(g.sweeper(min, max)). Use macro knob to sweep value.
// 14-bit MIDI mode.
g.sweeper = { |e, in, out|
    {
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
};