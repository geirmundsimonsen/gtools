g.bootWithRME = {
    s.options.device = "ASIO : ASIO Fireface USB";
    s.options.sampleRate = 96000;
    s.options.numInputBusChannels = 14;
    s.options.numOutputBusChannels = 14;
    s.reboot;
};
g.bootWithQuantum = {
    s.options.device = "ASIO : Quantum ASIO driver";
    s.options.sampleRate = 96000;
    s.options.numInputBusChannels = 40;
    s.options.numOutputBusChannels = 40;
    s.reboot;
};
g.bootWithMOTU = {
    s.options.device = "ASIO : MOTU Pro Audio";
    s.options.sampleRate = 96000;
    s.options.numInputBusChannels = 18;
    s.options.numOutputBusChannels = 18;
    s.reboot;
};