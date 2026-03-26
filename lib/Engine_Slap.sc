// Engine_Slap
// 4-part synth inspired by Fred's Lab instruments
// Part 0: MANATEE — spectral additive pads
// Part 1: ZEKIT — acid bass (additive saw + moog filter)
// Part 2: TOORO — hybrid morphing poly (varsaw + FM + analog filter)
// Part 3: BUZZZY! — multi-engine digital (pulse/FM/waves/noise + bitcrush)

Engine_Slap : CroneEngine {
  var synths;
  var part_params;
  var reverb_bus;
  var reverb_synth;

  *new { arg context, doneCallback;
    ^super.new(context, doneCallback);
  }

  alloc {
    synths = Array.fill(4, { nil });

    part_params = Array.fill(4, {
      Dictionary.newFrom([
        \cutoff, 2000, \res, 0.3, \pan, 0,
        \spread, 0.3, \brightness, 0.7,
        \accent, 0.5,
        \morph, 0.5, \fmamt, 0.3, \lfoRate, 2, \lfoDepth, 0.2,
        \engine_sel, 0, \pwm, 0.5, \fmRatio, 2, \fmIndex, 1, \bits, 10
      ]);
    });

    reverb_bus = Bus.audio(context.server, 2);

    // REVERB
    SynthDef(\slap_reverb, {
      arg in, out, mix=0.3, room=0.7, damp=0.5;
      var sig = In.ar(in, 2);
      sig = FreeVerb2.ar(sig[0], sig[1], mix, room, damp);
      Out.ar(out, sig);
    }).add;

    // MANATEE — Spectral Additive Pad
    SynthDef(\manatee, {
      arg out=0, freq=220, amp=0.3, gate=1,
          spread=0.3, brightness=0.7,
          cutoff=2000, res=0.3, pan=0;
      var sig, env;
      env = EnvGen.kr(Env.adsr(0.5, 0.4, 0.8, 1.2), gate, doneAction: 2);
      sig = Mix.fill(8, { |i|
        var h = i + 1;
        var drift = LFNoise1.kr(0.06 + (i * 0.015)).range(
          1 - (spread * 0.006),
          1 + (spread * 0.006)
        );
        SinOsc.ar(freq * h * drift) *
          (brightness.linlin(0, 1, 0.2, 1.8) / h.pow(1.4 - (brightness * 0.35)))
      });
      sig = MoogFF.ar(sig, cutoff.lag(0.12), res * 3);
      sig = sig * env * amp * 0.25;
      Out.ar(out, Pan2.ar(sig, pan));
    }).add;

    // ZEKIT — Acid Bass
    SynthDef(\zekit, {
      arg out=0, freq=110, amp=0.4, gate=1,
          cutoff=800, res=0.6, accent=0.5, pan=0;
      var sig, env, fenv;
      env = EnvGen.kr(Env.adsr(0.004, 0.12, 0.35, 0.18), gate, doneAction: 2);
      fenv = EnvGen.kr(Env.perc(0.004, 0.1)) * accent * 5000;
      sig = Mix.fill(8, { |i|
        var h = i + 1;
        SinOsc.ar(freq * h) * ((-1).pow(i + 1) / h)
      }) * 0.65;
      sig = MoogFF.ar(sig, (cutoff + fenv).clip(30, 16000), res * 3.5);
      sig = (sig * 2.5).tanh;
      sig = sig * env * amp * 0.35;
      Out.ar(out, Pan2.ar(sig, pan));
    }).add;

    // TOORO — Hybrid Morphing Poly
    SynthDef(\tooro, {
      arg out=0, freq=330, amp=0.35, gate=1,
          morph=0.5, fmamt=0.3, cutoff=3000, res=0.4,
          lfoRate=2, lfoDepth=0.2, pan=0;
      var sig, sig_fm, env, lfo;
      env = EnvGen.kr(Env.adsr(0.04, 0.25, 0.65, 0.4), gate, doneAction: 2);
      lfo = SinOsc.kr(lfoRate) * lfoDepth;
      sig = VarSaw.ar(freq, 0, morph.clip(0.01, 0.99));
      sig_fm = SinOsc.ar(freq + (SinOsc.ar(freq * 2) * freq * fmamt));
      sig = XFade2.ar(sig, sig_fm, morph.linlin(0, 1, -1, 1));
      sig = RLPF.ar(sig,
        (cutoff * (1 + (lfo * 0.35))).clip(30, 16000),
        (1 - (res * 0.85)).max(0.05)
      );
      sig = sig * env * amp * 0.35;
      Out.ar(out, Pan2.ar(sig, pan));
    }).add;

    // BUZZZY! — Multi-Engine Digital
    SynthDef(\buzzzy, {
      arg out=0, freq=440, amp=0.3, gate=1,
          engine_sel=0, pwm=0.5, fmRatio=2, fmIndex=1,
          bits=10, cutoff=5000, res=0.2, pan=0;
      var sig, env;
      env = EnvGen.kr(Env.perc(0.003, 0.35), gate, doneAction: 2);
      sig = Select.ar(engine_sel.round.clip(0, 3), [
        Pulse.ar(freq, pwm.clip(0.05, 0.95)),
        SinOsc.ar(freq + (SinOsc.ar(freq * fmRatio) * freq * fmIndex)),
        (VarSaw.ar(freq, 0, 0.3) + (Pulse.ar(freq * 0.5, 0.25) * 0.4)) * 0.65,
        BPF.ar(PinkNoise.ar, freq.max(60), 0.25) * 5
      ]);
      sig = sig.round(2.pow(bits.neg));
      sig = MoogFF.ar(sig, cutoff.clip(30, 16000), res * 2);
      sig = sig * env * amp * 0.4;
      Out.ar(out, Pan2.ar(sig, pan));
    }).add;

    context.server.sync;

    reverb_synth = Synth(\slap_reverb, [
      \in, reverb_bus, \out, context.out_b,
      \mix, 0.3, \room, 0.7, \damp, 0.5
    ], context.xg, \addAfter);

    // COMMANDS

    this.addCommand("note_on", "iff", { |msg|
      var part = msg[1].asInteger.clip(0, 3);
      var freq = msg[2].asFloat;
      var amp = msg[3].asFloat;
      var names = [\manatee, \zekit, \tooro, \buzzzy];
      var args;

      if(synths[part].notNil, { synths[part].set(\gate, 0) });

      args = List[\out, reverb_bus, \freq, freq, \amp, amp];
      part_params[part].keysValuesDo({ |k, v|
        args.add(k);
        args.add(v);
      });

      synths[part] = Synth(names[part], args.asArray, context.xg);
    });

    this.addCommand("note_off", "i", { |msg|
      var part = msg[1].asInteger.clip(0, 3);
      if(synths[part].notNil, {
        synths[part].set(\gate, 0);
        synths[part] = nil;
      });
    });

    this.addCommand("set_param", "isf", { |msg|
      var part = msg[1].asInteger.clip(0, 3);
      var param = msg[2].asSymbol;
      var val = msg[3].asFloat;
      part_params[part][param] = val;
      if(synths[part].notNil, {
        synths[part].set(param, val);
      });
    });

    this.addCommand("reverb_mix", "f", { |msg|
      reverb_synth.set(\mix, msg[1].asFloat);
    });

    this.addCommand("reverb_room", "f", { |msg|
      reverb_synth.set(\room, msg[1].asFloat);
    });

    this.addCommand("reverb_damp", "f", { |msg|
      reverb_synth.set(\damp, msg[1].asFloat);
    });
  }

  free {
    synths.do({ |s| if(s.notNil, { s.free }) });
    if(reverb_synth.notNil, { reverb_synth.free });
    if(reverb_bus.notNil, { reverb_bus.free });
  }
}
