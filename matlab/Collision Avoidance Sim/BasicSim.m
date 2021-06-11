clear
clc
close all

numberOfAgents = 7;
agentRadius = 1;
mapSize = 10;
timeStep = .05;
maxTime = 80;
maxVelocity = .5;
timeHorizon = 10;
sensingRange = 20;
velocityDiscritisation = 0.05;
vOptIsZero = true;
safetyMargin = 1.2;
responsibility = 0.5;
accelerationConstant = .5;

%initialize agent positions, velocities, and goal locations
% agentPositions = [-7,-8;8,-8];
% goalLocations = [8,8;-8,8];

% Random positions around a circle
agentPositions = zeros(numberOfAgents, 2);
goalLocations = zeros(numberOfAgents, 2);
for i = 1:numberOfAgents
theta = rand()*2*pi;
agentPositions(i,:) = [cos(theta),sin(theta)]*mapSize*(.7+(rand()-0.5)*.2);
goalLocations(i,:) = [cos(theta+pi),sin(theta+pi)]*mapSize*(.7+(rand()-0.5)*.2);
end

% agentPositions = zeros(numberOfAgents, 2);
% goalLocations = zeros(numberOfAgents, 2);
% for i = 1:numberOfAgents
%     theta = 2*pi/numberOfAgents * (i-1);
%     agentPositions(i,:) = [cos(theta),sin(theta)]*mapSize*(.9+(rand()-0.5)*.1);
%     goalLocations(i,:) = [cos(theta+3.9*pi/4),sin(theta+3.9*pi/4)]*mapSize*(.9+(rand()-0.5)*.1);
% end

agentVelocities = zeros(numberOfAgents,2);
path = zeros(length(0:timeStep:maxTime)-1,2,numberOfAgents);
counter = 0;
collisions = 0;

VOenv = velocityObstacleEnv(numberOfAgents);
VOenv = VOenv.setRT(2*agentRadius,timeHorizon);
VOenv = VOenv.setPlot(1,1,1);
VOenv = VOenv.addVector(1,'r',1);

for i = 2:numberOfAgents
    VOenv = VOenv.addGraphicsVO(1,i);
end

figPS = figure('Name', 'Position Space');
axis([-mapSize mapSize -mapSize mapSize])

lineGoalLocations = line;
set(lineGoalLocations, 'Marker', '*', ...
                       'LineStyle', 'none', ...
                       'Color', [1 0 0]);

for i = 1:numberOfAgents
    lineAgent(i) = line;
    textAgentNumber(i) = text;
    set(textAgentNumber(i), 'String', i)
    set(lineAgent(i),'color', 'b')
    linePath(i) = line;
    set(linePath(i),'color', 'b')
end

pause(1);

for t = 0:timeStep:maxTime
    counter = counter + 1;
    for i = 1:numberOfAgents
        path(counter,:,i) = agentPositions(i, :);
    end
    %Computes what velocity each robot wants to take
    velInput = (goalLocations - agentPositions)./vecnorm(goalLocations - agentPositions, 2, 2) * maxVelocity;
    
    velocityControls = ORCAController(agentPositions, agentVelocities, velInput, timeHorizon, sensingRange, agentRadius, maxVelocity, velocityDiscritisation, vOptIsZero, responsibility);
    
    [agentVelocities, numCollisions] = Collider(agentPositions, velocityControls, agentRadius, timeStep);
    
    %Increments velocity, then position
    agentPositions =  agentPositions + agentVelocities * timeStep;
    
    %Tallies collisions
    collisions = collisions + numCollisions;
   
    set(lineGoalLocations, 'xdata', goalLocations(:,1), ...
                          'ydata', goalLocations(:,2));
    for i = 1:numberOfAgents
        drawCircle(lineAgent(i),agentPositions(i,1), ...
                                agentPositions(i,2),agentRadius);
        set(linePath(i),'xdata',path(1:counter,1,i), ...
                        'ydata',path(1:counter,2,i));       
        set(textAgentNumber(i), "Position", [agentPositions(i,1)  ...
                                             agentPositions(i,2)]);
    end
    pause(0.01)
    
    VOenv = VOenv.setVO(agentPositions',1);
    VOenv.drawVector([0, agentVelocities(1,1), 0, agentVelocities(1,2)],1,1);
    VOenv.displayAgentVO(1,agentVelocities');
   
    if max(vecnorm(agentPositions - goalLocations,2,2)) < 0.2
        break; 
    end
end

% writerObj = VideoWriter('test1.avi');
% open(writerObj);
% 
% for i = 1:counter
% 
%     writeVideo(writerObj,F(i))
%     
% end
% close(writerObj);
