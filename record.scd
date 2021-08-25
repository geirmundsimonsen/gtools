g.record = {
    var phase = 1 - TempoClock.timeToNextBeat;
    var notes;
    var latency;
    var r = IdentityDictionary(know: true);

    r.type = 'record';
    r.start = 0;
    r.startTime = TempoClock.beats; 
    r.recording = SortedList(function: {|a, b| a.time < b.time });
    r.originalBeatDur = TempoClock.tempo.reciprocal;
    r.proto = g.recordProto;
    
    notes = 128.collect { |n| (pitch: n, sounding: false) };
    latency = Server.default.latency * TempoClock.tempo;

    MIDIdef('note_on_recorder', { |val, num, chan, src|
        notes[num].sounding = true;
        notes[num].time = TempoClock.beats - r.startTime - latency + phase;
        notes[num].amp = val / 127;
    }, nil, nil, 'noteOn');

    MIDIdef('note_off_recorder', { |val, num, chan, src|
        notes[num].sounding.if {
            notes[num].sounding = false;
            r.recording.add((
                pitch: num,
                amp: notes[num].amp,
                time: notes[num].time,
                length: (TempoClock.beats - r.startTime - latency + phase) - notes[num].time
            ));

            (r.recording.size == 1).if {
                (notes[num].time % 1 < 0.9).if {
                    r.start = notes[num].time.div(1);
                } {
                    r.start = notes[num].time.div(1) + 1;
                }
            };
        }
    }, nil, nil, 'noteOff');

    r;
};

g.recordProto = (
    stop: { |e|
        MIDIdef('note_on_recorder', {}, nil, nil, 'noteOn');
        MIDIdef('note_off_recorder', {}, nil, nil, 'noteOff');
    },
    play: { |e, sample, args=(())|
        var quant = args.quant ? 1;
        var length = args.length;
        var loopCount = args.loopCount ? 1;
        var quantize = args.quantize;
        var durseq, lengthseq, pitchseq;
        var rec = e.recording.deepCopy;

        quantize !? { |q| g.quantize(rec, q.resolution, q.strength) };
	
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
            [Env([item.amp, item.amp, 0], [item.length * e.originalBeatDur, 0.001])];
        };
        
        pitchseq = rec.collect { |item| item.pitch };
        
        Pbind(*((dur: Pseq(durseq, loopCount), env: Pseq(lengthseq, loopCount), pitch: Pseq(pitchseq, loopCount)) ++ g.sp(sample)).asPairs).play(quant: Quant(quant, phase: rec.first.time - e.start));
    }
);