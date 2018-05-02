function h = initializeInputParams(h)

h.minCh = 33;       % lowest channel number
h.maxCh = 64;       % highest channel number
h.selCh = h.minCh;

h.tmin  = 0;        % lower bound on plotted time window (default)
h.tmax  = 1;        % upper bound on plotted time window (default)

h.pullUpdatePeriod = 0.25;     % how often to pull spike data     
h.drawUpdatePeriod = 2;       % how often to update figures

% h.nRep  = 20;  % maximum number of stimuli repetitions for each type
h.sampling_freq = 30000;    % sampling rate for conversion of spiketimes to sec

% initialise data structures and arrays
h.IDreps = [];             % num of recorded reps per IDtype
h.plottedTrialNo = [];      
h.spikebuffer{h.maxCh,1}=[];
h.cmtbuffer = [];
h.cmttimesbuffer = [];
h.trialdata={};

%guidata(hObject,h);

end