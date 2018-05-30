function h = startTuningAll(h)
% startTuningAll(handles) initialises the tuning curves in the
% GUI_Online_PlotAll figure. handles is a struct that contains all the
% handles and userdata for this GUI.
%
% HN May 2018
%
% See also GUI_ONLINE_PLOTALL, GUIDATA

h1 = guidata(h.figure_master);

% h.numplots = 32; % hardcoded just for now
h.numplots = h1.maxCh-h1.minCh + 1;

yplots = floor(sqrt(h.numplots/2)); % approx twice as many x plots as y plots
xplots = ceil(h.numplots/yplots);

figure(h.figure1);      % draw into figure_plotAll
h.axes{1,h.numplots}=[];

param1 = h1.param1Select.Value;
h.tuning = nan(h.numplots,h1.nStim(param1));

for iplot=1:h.numplots
    % create and save handles to axes and lineplot separately
    h.axes{iplot} = subplot(yplots,xplots,iplot);
    h.lines{iplot} = plot(h.tuning(iplot,:),'-k.','MarkerSize',10);
    
    % adjust axes appearance
    h.axes{iplot}.XLim = [1 h1.nStim(param1)];
    h.axes{iplot}.YLimMode = 'auto';
    h.axes{iplot}.YLim(1) = 0;
    %h.axes{iplot}.XTick=[];
    %h.axes{iplot}.YTick=[];
end

% create plot update timer

h.drawAllTimer = timer('Period',h1.drawUpdatePeriod,...
    'TimerFcn',{@updateTuningAll,h.figure1},...
    'ExecutionMode','fixedSpacing',...
    'StartDelay',0.5 ...
    );
start(h.drawAllTimer);

% note: no final call to guidata to save handles structure, instead it is
% just passed back to GUI_Online_PlotAll_OpeningFcn, which adds other data
% to handles before saving it
end

%% timer callback
function updateTuningAll(~,~,f)
% Callback function for drawAllTimer. On every call, it recalculates tuning
% data for every channel (using spike data in h.spikedata) and updates the
% channel overview figure accordingly.

try 
    tuningsw = tic; % tuning stopwatch

    % fetch both handles
    h = guidata(f);
    h1 = guidata(h.figure_master);

    param1 = h1.param1Select.Value;
    param1str = h1.stimLabels{param1};
    
    n = h1.thisIdxs(param1);
    mask = h1.stimIdxs(:,param1)==n;

    % retrieve spikes and repetition count for this particular condition
    elapsedMask = h1.stimElapsed(h1.thisStim);
    spikesMasked = h1.spikedata(:,h1.thisStim,elapsedMask);

    h1.spikerate(:,h1.thisStim,elapsedMask) = cellfun(@(x) sum(x>=h1.tmin & x<=h1.tmax),spikesMasked)./(h1.tmax-h1.tmin);
    
    % if averaging across other params
    h.tuning(:,n) = mean(mean(h1.spikerate(:,mask,:),3),2,'omitnan');
    
    stopwatch(1) = toc(tuningsw)*1e3;
    
    tunedidxs = find(~isnan(h.tuning(1,:)));
    for iplot = 1 : h.numplots
        if ~isempty(h.tuning)
            h.lines{iplot}.XData = tunedidxs;
            h.lines{iplot}.YData = h.tuning(iplot,tunedidxs);
            % h.axes{iplot}.YLimMode = 'auto';
        else 
            
        end
    end
    guidata(h.figure1,h);
    guidata(h1.figure1,h1);
    fprintf("Overview | t = %f, %f\n",stopwatch(1),toc(tuningsw)*1e3);
catch err
    getReport(err)
    keyboard;
end

end