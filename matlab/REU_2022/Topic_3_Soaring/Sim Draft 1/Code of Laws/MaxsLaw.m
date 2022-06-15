classdef MaxsLaw
    properties
        %% Variables to save
        % Simulation constraints
        dt = 0.25;        %s
        totalTime = 240;  %s
        fpsMult = 10;
        mapSize = [-4000,4000];   %m, bounds of square map
        numAgents = 40;  %agents
        numThermals = 4; %thermals

        % Initial conditions
        agentSpawnPosRange = [-3000,-3000; 3000,3000];     %m, [xMin,yMin;xMax,yMax]
        agentSpawnAltiRange = [5,50];             %m, [Min,Max]
        agentSpawnVelRange = [8,0;13,0];           %m/s,rad/s [forwardMin,omegaMin;forwardMax,omegaMax];
        g = 9.81;                                  % m/s/s

        % Rule constraints
        separation = 1e6;
        cohesion = 1e-6;
        alignment = 1e6;
        migration = 1e-18;
        waggle = 50;

        % Agent constraints
        neighborRadius = 1000;     %m
        agentCeiling   = 100;    %m
        agentFloor     = 0;      %m
        forwardSpeedMin = 15;     %m/s
        forwardSpeedMax = 30;    %m/s
        forwardInertia = 10;
        bankMin = -5*pi/12;           %rad
        bankMax = 5*pi/12;            %rad
        bankInertia = 1;
        fov = 2*pi;              %rad
        Sink_A = -0.01843;
        Sink_B = 0.3782;
        Sink_C = -2.3782;

        % Thermal constraints
        tempThermalStrength = 10;
        thermalSpeedMin = 20;    % m/s
        thermalSpeedMax = 50;    % m/s
        thermalRadiusMin = 5;    % m
        thermalRadiusMax = 20;   % m
        thermalStrengthMin = 0;  % m/s, peak updraft speed
        thermalStrengthMax = 10; % m/s, peak updraft speed
        thermalFadeRate = 1;     % m/s, rate at which thermals fade in or out 
        thermalPlateauTime = 5;  % steps at a max or min strength

        %Visuals
        agentShape_triangle = [-0.5,0.5,-0.5; -0.375,0,0.375];
        agentShape_plane = [-0.5,-0.3,0,0.1,0.2,0.3,0.5,0.3,0.2,0.1,0,-0.3,-0.5;-0.2,-0.1,-0.1,-0.5,-0.5,-0.1,0,0.1,0.5,0.5,0.1,0.1,0.2];
        Arrow = [2 1.5 1.5 0 0 1.5 1.5; 0 .5 .1 .1 -.1 -.1 -.5];
        showArrow = false;
        renderScale = [300;300]; %[scaleX; scaleY];

        % Functions to use
        agentControlFuncName = "agentControl_Update";
    end
end

