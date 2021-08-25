g.sample = { |e, path, root=60|
    var s = IdentityDictionary(know: true);
    s.type = 'sample';
    s.path = path;
    s.root = root;
    s.buf = Buffer.read(Server.default, path);
    s.proto = g.sampleProto;
};

g.sampleProto = (
    reduceForArchiving: { |e|
        e.removeAt('buf');
    },
    prepareForUse: { |e|
        e.buf = Buffer.read(Server.default, e.path);
    }
);