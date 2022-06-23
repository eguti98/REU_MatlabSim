classdef ColesLaw
    properties
        %% Variables to save
        % Simulation constraints
        dt = 0.1;        %s
        totalTime = 60;  %s
        fpsMult = 1;
        mapSize = [-200,200];   %m, bounds of square map
        numAgents = 50;  %agents

        % Initial conditions
        agentSpawnPosRange = [-200,-200; 200,200];     %m, [xMin,yMin;xMax,yMax]
        agentSpawnAltiRange = [80,80];             %m, [Min,Max]
        agentSpawnVelRange = [8,0;13,0];           %m/s,rad/s [forwardMin,omegaMin;forwardMax,omegaMax];
        g = 9.81;                                  % m/s/s

        % Rule constraints
        separation = 7;
        separationHeightGap = 10;
        cohesion = 0.008;
        cohesionHeightMult = 8;
        alignment = 3;
        migration = 1*2e-12;
        waggle = 0.5;

        % Agent constraints
        neighborRadius = 80;     %m
        k = 5; %k-nearest neighbors
        agentCeiling   = 100;    %m
        agentFloor     = 0;      %m
        forwardSpeedMin = 15;     %m/s
        forwardSpeedMax = 15;    %m/s
        forwardInertia = 10;
        bankMin = -5*pi/12;           %rad
        bankMax = 5*pi/12;            %rad
        bankInertia = 1;
        fov = 2*pi;              %rad
        Sink_A = -0.01843;
        Sink_B = 0.3782;
        Sink_C = -2.3782;

        %Visuals
        agentShape_triangle = [-0.5,0.5,-0.5; -0.375,0,0.375];
        agentShape_plane = [-0.5,-0.3,0,0.1,0.2,0.3,0.5,0.3,0.2,0.1,0,-0.3,-0.5;-0.2,-0.1,-0.1,-0.5,-0.5,-0.1,0,0.1,0.5,0.5,0.1,0.1,0.2];
        Arrow = [2 1.5 1.5 0 0 1.5 1.5; 0 .5 .2 .2 -.2 -.2 -.5];
        showArrow = false;
        renderScale = [8;8]; %[scaleX; scaleY];
        showKNN = true;
        showFixedRadius = false;

        % Functions to use
        funcName_agentControl = "agentControl_KNN";
        funcName_findNeighborhood = "findNeighborhood_KNN";
        
    end
    
    methods
        function strength = getTempThermalStrength(~,agent)
            position = agent.position;
            radius = 50;
            peakStrength = 20;
            thermalPos = [-0,-0];
            
            dist = norm(position(1:2)-thermalPos);
            closeStrength = peakStrength*(1-(dist/radius)^2);
            strength = max(0,closeStrength);
        end
    end
end
