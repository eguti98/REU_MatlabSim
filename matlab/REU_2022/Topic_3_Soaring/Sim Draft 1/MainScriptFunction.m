function [average, surviving, flightTime, ToD, Log] = MainScriptFunction(Param, render)
% Main script: loads parameter variables and runs swarm step function
%% Clear
close all
%clear
%clc

%% Add search paths for sim laws and agent functions
addpath("Code of Laws");
addpath("Agent Control Functions");
addpath("Find Neighborhood Functions");

%% Load simulation parameters
SL = MaxsLaw();
% Initialize thermals as a matrix of Thermals
thermalMap = ThermalMap(SL);


number                  = Param(1);
SL.separation           = 10^Param(2);
SL.cohesion             = 10^Param(3);
SL.alignment            = 10^Param(4);
SL.migration            = 10^Param(5);
SL.cohesionHeightMult   = Param(6);
SL.separationHeightGap  = Param(7);
SL.dt                   = Param(8);
SL.waggle               = Param(9);
SL.waggleTime           = Param(10);
SL.numAgents            = Param(11);

swarm = Swarm(SL, thermalMap);


%% Video Initialization...
dateFormat = "mm-dd-yy";
timeFormat = "HH-MM-SS";
% Get current date/time
date = datestr(now,dateFormat);
time = datestr(now,timeFormat);

if render
    %% setup output folder
    rootFolder = "Output Media";
    % Create folder/video names
    dateFolder = sprintf('%s/%s',rootFolder,date);

    % Create folders if they don't exist
    if(~exist(rootFolder,'dir'))
        mkdir(rootFolder);
    end
    if(~exist(dateFolder,'dir'))
        mkdir(dateFolder);
    end

    %% Setup video and figure
%     videoPrefix = sprintf('[dt %g, T %g, x%g] ',simLaw.dt, simLaw.totalTime, simLaw.fpsMult);
    videoPrefix = "BIG";
    videoSuffix = time;
%    videoSuffix = sprintf('%1.0E, %1.0E, %1.0E', simLaw.separation, simLaw.cohesion, simLaw.alignment);
    videoName = sprintf('%s/%s %s.avi',dateFolder,videoPrefix,videoSuffix);

    video = VideoWriter(videoName);
    video.FrameRate = 1/SL.dt * SL.fpsMult / SL.frameSkip;
    open(video);
    
    simFig = figure('Visible','on');

    % Initialize map background
    clf
    xlim(SL.mapSize);
    ylim(SL.mapSize);
    daspect([1 1 1]);
    colorbar;
    cbLimits = [-1,SL.thermalStrengthMax];
    colors = [6 42 127; 41 76 247; 102 59 231; 162 41 216; 222 24 200; 255 192 203] / 255;
    x = [0:thermalMap.thermalPixels/(length(colors)-1):thermalMap.thermalPixels];
    map = interp1(x/thermalMap.thermalPixels,colors,linspace(0,1,thermalMap.thermalPixels)); % Creates a color gradient for the map
    colormap();%map);
    set(gca,'clim',cbLimits);
end

%% Run simulation...
steps  = SL.totalTime/SL.dt;
Living = SL.numAgents;
maxHeight     = -1;
minHeight     = 1E6;
averageHeight = 0;
flightTime          = 0;
ToD           = zeros(1,SL.numAgents);

for step = 1:steps
    if nnz([swarm.agents.isAlive]) > 0
        %% Step simulation & Get Data
        thermalMap.staticStep();
    
        swarm.saveAgentData();
        swarm.stepSimulation();
        averageHeight = 0;
        for i=1:SL.numAgents
            if swarm.agents(i).isAlive
                currentHeight = swarm.agents(i).position(3);
                maxHeight = max(maxHeight,currentHeight);
                minHeight = min(minHeight,currentHeight);
                averageHeight = averageHeight + currentHeight;
            end
        end
        averageHeight = averageHeight / nnz([swarm.agents.isAlive]);
        minutes = floor(step*SL.dt/60);
        seconds = mod(floor(step*SL.dt),60);
        if Living ~= nnz([swarm.agents.isAlive])
            % if living is suddenly 39/40, update number 1 to whatever time it
            % is now.
            % if multiple agents die, update that number of elements.
            % Living should always be >= nnz of isAlive; isAlive updates first.
            ToD((SL.numAgents - Living + 1) : (SL.numAgents - nnz([swarm.agents.isAlive]))) = minutes;
        end
    
        Living  = nnz([swarm.agents.isAlive]);
        flightTime    = flightTime + Living * SL.dt;
    
        
        %% Render
        if render && mod(step,SL.frameSkip)==0
            hold on
    
            thermalMap.renderThermals();
            swarm.renderAgents();
            xlim([swarm.agents(swarm.thisAgent).position(1) - 1000, swarm.agents(swarm.thisAgent).position(1) + 1000]);
            ylim([swarm.agents(swarm.thisAgent).position(2) - 1000, swarm.agents(swarm.thisAgent).position(2) + 1000]);
            %xlim(SL.mapSize);
            %ylim(SL.mapSize);
            ax = gca;
            ax.PositionConstraint = 'outerposition';

            currFrame = getframe(simFig);
            writeVideo(video,currFrame);
            pause(0.0001);
    
    %         stringTitle = sprintf("Agents Alive: %g\nMax Height: %.1f\nMin Height: %.1f\nAverage Height: %.1f",Living,maxHeight,minHeight,averageHeight);
    %         stringTitle = sprintf("Minutes: %g\nAgents Alive: %g\nAverage Height: %.1f",minutes,Living,averageHeight);
            stringTitle = sprintf("Number %g, T+%02g:%02g, Total Time = %5.0f\nAgents Alive: %g  Average Height: %.1f", ...
                number, minutes, seconds,flightTime, Living,averageHeight);
            title(stringTitle);
            hold off
        end
        
        %% Print
        if mod(step,steps/10) == 0
            fprintf("%02.2f%%, ",100*step/steps);
            fprintf("Run # %g \n", number);
            % fprintf("%g Agents\n ", Living);
        end
    else
        fprintf("Everybody died\n");
        break
    end

end
average = averageHeight;
surviving = Living;
if render 
    close(video); 
end

%% Write to Log

% Date	Time	Separation	Cohesion	Alignment	
% Migration	Height-Priority	Height-Ignore	dt	Waggle-Strength	
% Waggle-Time	# of Agents	Total-Time	# of Thermals	Neighbor-Radius	
% 	K	FOV	Surviving	Average Z of survivors	
% Flight Time

timeFormat2 = "HH:MM:SS";
time = datestr(now,timeFormat2);

Log = {date, time, SL.separation, SL.cohesion, SL.alignment,...
       SL.migration, SL.cohesionHeightMult, SL.separationHeightGap, SL.dt, SL.waggle,...
       SL.waggleTime, SL.numAgents, SL.totalTime, SL.numThermals, SL.neighborRadius,...
       SL.k, SL.fov, surviving, average, flightTime};


end