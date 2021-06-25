clc
clear
close all
%   World Building
numberOfAgents = 6;
agentRadius = .5;
timeStep = .05;
mapSize = 10;
counter = 0;


f = @testController;

ENV = agentEnv(numberOfAgents,agentRadius,mapSize,timeStep); 


initPositions = [-8,-8;-8,-7;-8,-6;-8,-5;-8,-4;-8,-3];
goalLocations = 5.*ones(numberOfAgents,2); 

ENV.setAgentPositions(initPositions);
ENV.setGoalPositions(goalLocations);
ENV.setAgentVelocities(zeros(numberOfAgents,2));
for i = 1:numberOfAgents
    ENV.agents(i).setController(f);
end 
ENV.pathVisibility(true);

while(true)
    ENV.tick;
    counter = counter + 1;
    fprintf("Time: %i \n",counter)
    if counter > 2000
       break 
    end
    ENV.agents(1).getTimeStep;
end
ENV.collisions





