classdef MaxsLaw
    properties
        %% Variables to be Changed Here
        % Simulation
        totalTime = 7200;           % s
        fpsMult = 60;               % x Real Time
        numThermals = 6;            % thermals
        neighborRadius = 4000;      % m
        k = 10;                      % number of nearest neighbors
        frameSkip = 5;             % render every nth frame
        forwardInertia = 10;        % <unused>
        bankMin = -2*pi/12;         % rad
        bankMax = 2*pi/12;          % rad
        bankInertia = 1;            % <unused>
        fov = 2*pi;                 % rad
        forwardSpeedMin = 8;        % m/s
        forwardSpeedMax = 13;       % m/s
        
        % Visuals
        showArrow = false;          %
        followAgent = false;        %
        followRadius = 1000;
        renderScale = [200;200];    % [scaleX; scaleY];
        showNeighbors = true;       %
        showFixedRadius = false;     %
        showRange = false;           %
        showText  = false;          %
        stopWhenDead = true;        %

        % Functions to use
        funcName_agentControl     = "agentControl_Max";
        funcName_findNeighborhood = "findNeighborhood_KNNInFixedRadius";

        % Thermal constraints
        thermalPixels = 50
        thermalSpeedMin = 0         % m/s
        thermalSpeedMax = 0         % m/s
        thermalRadiusMin = 600      % m
        thermalRadiusMax = 1300     % m
        thermalStrengthMin = 1      % m/s, peak updraft speed
        thermalStrengthMax = 10     % m/s, peak updraft speed
        thermalFadeRate = 0.001     % m/s, rate at which thermals fade in or out 
        thermalMinPlateauTime = 1600% steps at the min strength
        thermalMaxPlateauTime = 1000% steps at the max strength
        thermalSpawnAttempts = 75;  % number of attempts

        %% Variables that get changed in the Excel Doc
        separation = 1;
        cohesion   = 1;
        alignment  = 1;
        migration  = 1e-21;
        % these two are kind of the same
        heightPriority = 5;         % For agentControl_Update
        cohesionHeightMult = 5;     % For agentControl_KNN 
        % these two are not at all the same
        heightIgnore = 0.2;         % For agentControl_Update
        separationHeightGap = 2;    % For agentControl_KNN
        
        dt = .1;                    % s
        waggle = pi/48;             % Radians of bank
        waggleTime = 1;             % Seconds of waggle bank        
        numAgents = 40;             % agents
        

        %% Not to Change
        % Initial conditions
        mapSize = [-4000,4000];     % m, bounds of square map
        agentSpawnPosRange = [-3000,-3000; 3000,3000];  % m, [xMin,yMin;xMax,yMax]
        agentSpawnAltiRange = [1600,1600];              % m, [Min,Max]
        agentSpawnVelRange = [8,0;13,0];                % m/s,rad/s [forwardMin,omegaMin;forwardMax,omegaMax];
        g = 9.81;   
        
        % Visuals
        agentShape_triangle = [-0.5,0.5,-0.5; -0.375,0,0.375];
        agentShape_plane = [-0.5,-0.3,0,0.1,0.2,0.3,0.5,0.3,0.2,0.1,0,-0.3,-0.5;-0.2,-0.1,-0.1,-0.5,-0.5,-0.1,0,0.1,0.5,0.5,0.1,0.1,0.2];
        agentShape_amogus = [.25 .5 0 0 .5 .5 .15 .15 -.15 -.15 -.5 -.5 -.75 -.75 -.25;
                             .75 .4 .4 .15 .15 -1 -1 -.6 -.6 -1 -1 -.55 -.25 .25 .75];
        Arrow = [2 1.5 1.5 0 0 1.5 1.5; 0 .5 .1 .1 -.1 -.1 -.5];
        ThermPatch = [0.8660, 0.5000, 0.0000, -0.5000, -0.8660, -1.0000, -0.8660, -0.5000, -0.0000,  0.5000,  0.8660,  1.0000;
                      0.5000, 0.8660, 1.0000,  0.8660,  0.5000,  0.0000, -0.5000, -0.8660, -1.0000, -0.8660, -0.5000, -0.0000];
        CMColors = [6 42 127; 41 76 247; 102 59 231; 162 41 216; 222 24 200; 255 192 203] / 255;
        
        % Agent Constants
        agentCeiling   = 2600;      % m
        agentFloor     = 0;         % m
        Sink_A = -0.01843;          %
        Sink_B = 0.3782;            %
        Sink_C = -2.3782;           %
    end
end

