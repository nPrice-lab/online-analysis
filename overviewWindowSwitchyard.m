function f = overviewWindowSwitchyard()
f.open = @openOverviewWindow;
f.update = @updateOverviewWindow;
f.close = @closeOverviewWindow;
end


% % ========== INITIALISATION FUNCTION ====================================
function openOverviewWindow(f_master)

% initialise handles, fetch master handles
h = struct;
h.figure_master = f_master;
h1 = guidata(f_master);

% create figure, save to handles
f = figure(2);
h.figure1 = f;
h1.figure_overview=f;

% set figure position and other properties
f.CloseRequestFcn = @closeOverviewWindow;
res = get(groot, 'Screensize');
% NOTE: positioning is a bit finicky and it seems like OuterPosition takes
% into account some misc Windows 10 UI elements of unknown size. haven't
% yet found a more reliable way to tile windows to occupy 100% of desktop
% space while leaving room for Windows taskbar, startbar, etc...
f.OuterPosition = f_master.OuterPosition;  % initialise to same position as master
f.OuterPosition(1) = f_master.Position(3); % then shift to right 85% of screen
f.OuterPosition(3) = res(3)-f.OuterPosition(1)+7;

% disable Overview settings until Overview is closed ?
h1.channelInput.Enable = 'Off';
h1.timeWinInput.Enable = 'Off';
h1.param1Select.Enable = 'Off';
h1.param2Select.Enable = 'Off';
h1.param2ValSelect.Enable = 'Off';


% save some data to handles
h.param1 = h1.param1Select.Value;
h.numplots = h1.maxChO-h1.minChO + 1;
h.spikerate = h1.spikerate; % copy empty array of correct size
h.tuning = nan(h.numplots,h1.nStim(h.param1));

% start drawing subplots
yplots = round(sqrt(h.numplots/2)); % approx twice as many x plots as y plots
xplots = ceil(h.numplots/yplots);
h.param2 = find(strcmp(h1.param2Select.String{h1.param2Select.Value},h1.stimLabels));
param2Idx = str2double(h1.param2ValSelect.String{h1.param2ValSelect.Value});
if isnan(param2Idx)
    h.param2Val = 0;
else
    h.param2Val = find(param2Idx==h1.stimVals(h.param2,:));
end

if h1.param2Select.Value > 1       % Param 2 selected
    if h.param2Val == 0             % "Show all"
        numCurves = h1.nStim(h.param2);
        h.tuning = repmat(h.tuning,[1 1 numCurves]);
    end 
end

for iplot=1:h.numplots
    % create and save handles to axes and lineplot separately
    h.axes{iplot} = subplot(yplots,xplots,iplot);
    if h1.param2Select.Value>1 && h.param2Val == 0             % "Show all"
        hold on
        for iCurve = 1:numCurves
            h.lines{iplot,iCurve} = plot(h.tuning(iplot,:),'-.','MarkerSize',10);
        end
        hold off
    else
        h.lines{iplot} = plot(h.tuning(iplot,:),'-k.','MarkerSize',10);
    end
    
    % attach Focus callback
    focusWindow = focusWindowSwitchyard();
    h.axes{iplot}.ButtonDownFcn = {focusWindow.open,h.figure_master,iplot};
    
    % adjust axes appearance
    h.axes{iplot}.XLimMode = 'auto';
    h.axes{iplot}.YLimMode = 'auto';
    
    if iplot==((yplots-1)*xplots+1)   % axes label on bottom left subplot
        h.axes{iplot}.YLabel.String = 'Firing rate (spikes/s)';
        h.axes{iplot}.XLabel.String = h1.stimLabels{h.param1};
    end
end

% calculate and draw initial tuning
% % % h.spikerate = cellfun(@(x) sum(x>=h1.tmin & x<=h1.tmax),h1.spikedata)./(h1.tmax-h1.tmin);
% cellfun is, for some reason, incredibly slow for this task. hence the for
% loops, which are ~100x faster. could implement a cellfun2 fcn to do the
% below instead
h.spikerate = zeros(size(h1.spikedata));

for stim = 1:size(h1.spikedata,2)
for elap = 1:size(h1.spikedata,3)
    if elap>h1.stimElapsed(stim)
        h.spikerate(:,stim,elap) = nan;
    else
        for ch = h1.minChO:h1.maxChO
            spikes=h1.spikedata{ch,stim,elap};
            h.spikerate(ch,stim,elap) = sum(spikes>=h1.tmin & spikes<h1.tmax);
        end        
    end
end
end
h.spikerate = h.spikerate/(h1.tmax-h1.tmin);

for n=1:h1.nStim(h.param1)
    mask = h1.stimIdxs(:,h.param1)==n;
    spikerateMasked = h.spikerate(h1.minChO:h1.maxChO,mask,:);
    if h1.param2Select.Value == 1   % 'All': average across all other params
        h.tuning(:,n) = mean(mean(spikerateMasked,3,'omitnan'),2,'omitnan');
    end
end
if h1.param2Select.Value>1 && h.param2Val == 0
    tunedidxs = find(~isnan(h.tuning(1,:,n2)));
else
    tunedidxs = find(~isnan(h.tuning(1,:)));
end

for iplot = 1 : h.numplots
    if h1.param2Select.Value>1 && h.param2Val == 0
        h.lines{iplot,n2}.XData = h1.stimVals(h.param1,tunedidxs);
        h.lines{iplot,n2}.YData = h.tuning(iplot,tunedidxs,n2);
    else
        h.lines{iplot}.XData = h1.stimVals(h.param1,tunedidxs);
        h.lines{iplot}.YData = h.tuning(iplot,tunedidxs);
    end
    h.axes{iplot}.XLim = [min(h1.stimVals(h.param1,:)),Inf];
    h.axes{iplot}.YLimMode = 'auto';
    h.axes{iplot}.YLim(1) = 0;
end

% save all app data
guidata(f,h);
guidata(f_master,h1);

end


% % ========== UPDATE FUNCTION ============================================
function updateOverviewWindow(f)
try 
    tuningsw = tic; % tuning stopwatch
    % fetch both handles
    h = guidata(f);
    h1 = guidata(h.figure_master);
    
    if h1.param2Select.Value>1 && h.param2Val>0 && h.param2Val~=h1.thisIdxs(h.param2)
        % skip!
    else

        % retrieve mask for all conditions that match this one in param 1 value
        n = h1.thisIdxs(h.param1);
        mask = h1.stimIdxs(:,h.param1)==n;

        % retrieve spikes and repetition count for this particular condition
        elapsedMask = h1.stimElapsed(h1.thisStim);
        thisSpikes = h1.spikedata(h1.minChO:h1.maxChO,h1.thisStim,elapsedMask);

    %     % fill spikerate with NaNs as it increases
    %     [srx,sry,srz] = size(h.spikerate);
    %     if elapsedMask>srz
    %         h.spikerate(:,:,srz+1:elapsedMask) = nan(sthisrx,sry);
    %     end

        % calculate spikerate for this stim
        for ch = h1.minChO:h1.maxChO
            h.spikerate(ch,h1.thisStim,elapsedMask) = sum(thisSpikes{ch}>=h1.tmin & thisSpikes{ch}<h1.tmax);
        end
        
        % retrieve all spikerates in mask
        spikerateMasked = h.spikerate(h1.minChO:h1.maxChO,mask,:);

        if h1.param2Select.Value == 1   % 'All': average across all other params
            h.tuning(:,n) = mean(mean(spikerateMasked,3,'omitnan'),2,'omitnan');
        else
            % produce second-order mask (i.e. all conditions in current mask that
            % match current condition in param 2 value)
            stimIdxsMasked = h1.stimIdxs(mask,:);
            n2 = h1.thisIdxs(h.param2);
            mask2 = stimIdxsMasked(:,h.param2) == n2;

            % apply second-order mask
            spikerateMasked2 = spikerateMasked(h1.minChO:h1.maxChO,mask2,:);

            if (h.param2Val==0) % "Show all"
                h.tuning(:,n,n2) = mean(mean(spikerateMasked2,3),2,'omitnan');
            else
                h.tuning(:,n) = mean(mean(spikerateMasked2,3),2,'omitnan');
            end
        end
        stopwatch(1) = toc(tuningsw)*1e3;

        if h1.param2Select.Value>1 && h.param2Val == 0
            tunedidxs = find(~isnan(h.tuning(1,:,n2)));
        else
            tunedidxs = find(~isnan(h.tuning(1,:)));
        end

        stopwatch(2) = toc(tuningsw)*1e3;
        for iplot = 1 : h.numplots
            if h1.param2Select.Value>1 && h.param2Val == 0
                h.lines{iplot,n2}.XData = h1.stimVals(h.param1,tunedidxs);
                h.lines{iplot,n2}.YData = h.tuning(iplot,tunedidxs,n2);
            else
                h.lines{iplot}.XData = h1.stimVals(h.param1,tunedidxs);
                h.lines{iplot}.YData = h.tuning(iplot,tunedidxs);
            end

            h.axes{iplot}.XLim = [min(h1.stimVals(h.param1,:)),Inf];
            h.axes{iplot}.YLimMode = 'auto';
            h.axes{iplot}.YLim(1) = 0;
        end
        
        guidata(h.figure1,h);
        guidata(h1.figure1,h1);
        if (h1.verbose)
            fprintf("Overview | t = %f, %f, %f\n",stopwatch(1),stopwatch(2),toc(tuningsw)*1e3);
        end
    end
catch err
    getReport(err)
    keyboard;
end
end


% % ========== CLOSE FUNCTION =============================================
function closeOverviewWindow(f,~)
% reenable Overview settings
h = guidata(f);
h1 = guidata(h.figure_master);
try
    h1.channelInput.Enable = 'On';
    h1.timeWinInput.Enable = 'On';
    h1.param1Select.Enable = 'On';
    h1.param2Select.Enable = 'On';
    if h1.param2Select.Value>1
        h1.param2ValSelect.Enable = 'On';
    end
catch
    keyboard;
end
% then close figure
delete(f);
end
