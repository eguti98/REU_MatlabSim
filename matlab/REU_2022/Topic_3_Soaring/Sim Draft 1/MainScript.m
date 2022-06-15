% Main script: loads parameter variables and runs swarm step function
%% Clear
close all
clear
clc

%% Add search paths for sim laws and agent functions
addpath("Code of Laws");
addpath("Agent Control Functions");

%% Load simulation parameters
simLaw = AdamsLaw();

%% setup output folder
rootFolder = "Output Media";
dateFormat = "mm-dd-yy";
timeFormat = "HH-MM-SS";
videoPrefix = "TestVideo";
%videoPrefix = sprintf('[dt %g, T %g, x%g] ',simLaw.dt, simLaw.totalTime, simLaw.fpsMult);

% Get current date/time
date = datestr(now,dateFormat);
time = datestr(now,timeFormat);

% Create folder/video names
dateFolder = sprintf('%s/%s',rootFolder,date);


%videoSuffix = sprintf('S=%1.0E, C=%1.0E, A=%1.0E, M=%1.0E', simLaw.separation, simLaw.cohesion, simLaw.alignment, simLaw.migration);
%videoName = sprintf('%s/%s %s.avi',dateFolder,videoPrefix,videoSuffix);
videoName = sprintf('%s/%s %s.avi',dateFolder,videoPrefix,time);

% Create folders if they don't exist
if(~exist(rootFolder,'dir'))
    mkdir(rootFolder);
end

if(~exist(dateFolder,'dir'))
    mkdir(dateFolder);
end

%% Setup video and figure
video = VideoWriter(videoName);
video.FrameRate = 1/simLaw.dt * simLaw.fpsMult;
open(video);

simFig = figure('Visible','on');
xlim(simLaw.mapSize);
ylim(simLaw.mapSize);
daspect([1 1 1])

%% Create instance of simulation
swarm = Swarm(simLaw);
theta = linspace(0,2*pi,50);
patchX = 50*cos(theta)-100;
patchY = 50*sin(theta)+100;
patchObj = patch('XData',patchX,'YData',patchY,'FaceColor','red','FaceAlpha',0.8);

%% Run simulation
steps = simLaw.totalTime/simLaw.dt;
for step = 1:steps
    c1 = clock;
    fprintf("Frame %g/%g:  ",step,steps);
    
    % Render agents
    swarm.renderAgents();
    
    % Save video frame
    currFrame = getframe(simFig);
    writeVideo(video,currFrame);
    pause(0.0001);
    
    % Step simulation
    swarm.saveAgentData();
    swarm.stepSimulation();
    
    % Print number of Living Agents
    Living = nnz([swarm.agents.isAlive]);
    fprintf("%g Agents, ", Living);
    stringLiving = sprintf("%g Agents Alive",Living);
    title(stringLiving);

    % Find and print elapsed time
    c2 = clock;
    elapsedTime = c2(6)-c1(6);
    % If minute advances, elapsedTime will appear negative (1min20sec - 0min50sec = 20sec-50sec = -30sec)
    if(elapsedTime < 0) 
        elapsedTime = elapsedTime + 60;
    end
    fprintf("%g sec\n",elapsedTime);
end

close(video);