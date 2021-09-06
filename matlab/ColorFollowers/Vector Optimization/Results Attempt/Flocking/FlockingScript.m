clear
close all;
clc

%% Setting Up Sim
%   World Building
numberOfAgents = 20;
numberOfGroups = 1;
agentRadius = .5;
timeStep = .05;
mapSize = 30;
counter = 0;
maxSpeed = 10;
sensingRange = 4; %16
connectionRange = 2;
newParameters = zeros(5,1);
display = true;
timeSteps = 1000;

spawnType = 'random';
%spawnType = 'opposingGroups';

%Set f to appropriate controller handle
f = @FlockingController;

%Set up the environment
ENV = agentEnv(numberOfAgents,agentRadius,mapSize,timeStep); 

%Spawn the agents using a custom spawn function
[initPositions, goalLocations] = FlockingSpawn(numberOfAgents, spawnType, mapSize);

%Set some variables in the environment
ENV.setAgentPositions(initPositions);
ENV.setGoalPositions(goalLocations);
ENV.setAgentVelocities(zeros(numberOfAgents,2));
ENV.realTime = false;
ENV.pathVisibility(false);
ENV.collisions = true;

%Set some variables for each agent
for i = 1:numberOfAgents
    ENV.agents(i).setController(f);
    ENV.agents(i).createProperty('group',mod(i,numberOfGroups)+1);
    ENV.agents(i).measuringRange = sensingRange;
    ENV.agents(i).maxSpeed = maxSpeed;
    ENV.agents(i).velocity = [maxSpeed*2*(rand()-0.5), maxSpeed*2*(rand()-0.5)];
end 

%% Running Sim
cost = 0;
while(true)
    customTick(ENV, timeStep, display, mapSize);
    counter = counter + 1;
    fprintf("Time: %i \n",counter)
    if counter > timeSteps
        break
    end
    F(counter) = getframe(gcf);
    
end
%     video = VideoWriter('Flocking3', 'MPEG-4');
%     open(video);
%     writeVideo(video, F);
%     close(video)


%% Required Functions
    function customTick(ENV, timeStep, display, mapSize)
            for ii = 1:length(ENV.agents)
                ENV.agents(ii).callMeasurement(ENV);
                ENV.agents(ii).callController;     
                customPhys(ENV, ii, timeStep);
                ENV.updateAgentPath(ii,ENV.agents(ii).pose);
            end
            if display
                customDraw(ENV, mapSize);
            end
    end
    function customDraw(ENV, mapSize)
        figure(1);
        cla;
            hold on
            xlim([-mapSize*2,mapSize*2]);
            ylim([-mapSize*2,mapSize*2]);
            for ii = 1:length(ENV.agents)
                
                RGB = ENV.agents(ii).color;
                %RGB = RGB/256;
                plot(ENV.agents(ii).pose(1), ENV.agents(ii).pose(2), '.', 'MarkerEdge', RGB, 'MarkerSize', 25);
                if length(ENV.agents(ii).path(:,1)) > 10
                    plot(ENV.agents(ii).path(end-10:end, 1), ENV.agents(ii).path(end-10:end, 2), '.', 'MarkerEdge', RGB);
                else
                    plot(ENV.agents(ii).path(:, 1), ENV.agents(ii).path(:, 2), '.', 'MarkerEdge', RGB);
                end
                set(gca,'Color','k');
            end
            hold off
            pause(0.075)
    end
    function customPhys(ENV,id, timeStep)
        controlVel = ENV.agents(id).velocityControl;
        ENV.agents(id).velocity = controlVel;
        ENV.agents(id).pose = ENV.agents(id).pose + ENV.agents(id).velocity*timeStep;
    end
    
