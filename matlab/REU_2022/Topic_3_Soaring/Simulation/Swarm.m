% Swarm class
classdef Swarm < handle
    properties
        agents
        simLaw
        funcHandle_agentControl
        funcHandle_findNeighborhood
        thisAgent = 1;
        heroAgent
        thermalMap
        simFig
        video
        ax
        colorbars
        
        lineCircle = NaN
        lineNeighbors = NaN
        lineRange = NaN
        patchSep = NaN
        patchCoh = NaN
        patchAli = NaN
        patchMig = NaN
        patchWag = NaN

        textAnnt = NaN
        number  = 0                 % 
        Elapsed = [0.0 0.0 0.0]     % hours, minutes, seconds
        Living = 0                  %
        avgHeight = 0           % m
        minHeight = 0               % m
        maxHeight = 0               % m
        avgSpeed  = 0               % m/s
        ToD
        collisionDeaths = 0
        groundDeaths = 0
        
        flightTime = 0.0            % Agent-seconds
        heightScore = 0.0           % m-seconds
        thermalUseScore = 0.0       % Agent-seconds
        mapDivisions
        mapDivSize
        explorationPercent = 0.0    % Percent
    end
    
    methods
        % Generation Function
        function obj = Swarm(simLaw,thermalMap,simNumber)
            % Save parameters and agentControlFunc
            obj.simLaw = simLaw;
            obj.thermalMap = thermalMap;
            obj.number = simNumber;
            SL = obj.simLaw;

            obj.funcHandle_agentControl = str2func(SL.funcName_agentControl);
            obj.funcHandle_findNeighborhood = str2func(SL.funcName_findNeighborhood);
            obj.ToD = zeros(1,SL.numAgents);
            
            %% Generate agents
            numAgents = SL.numAgents;   %Get total number of agents
            obj.agents = Agent.empty(0,SL.numAgents);
            obj.agents(1,numAgents) = Agent();  %Fill agents with default constructors of Agent
            obj.heroAgent = obj.agents(1); % hero is number one

            %Iterate through all agents
            posRange = SL.agentSpawnPosRange;
            velRange = SL.agentSpawnVelRange;
            altiRange = SL.agentSpawnAltiRange;
            for i=1:numAgents
                obj.agents(i).simLaw = SL;
                %Set agent initial position, heading, bank angle, velocity
                obj.agents(i).position(1) = Utility.randIR(posRange(1,1),posRange(2,1));
                obj.agents(i).position(2) = Utility.randIR(posRange(1,2),posRange(2,2));
                obj.agents(i).position(3) = Utility.randIR(altiRange(1),altiRange(2));
                obj.agents(i).heading = Utility.randIR(0,2*pi); %rad
                obj.agents(i).bankAngle = 0; %rad
                obj.agents(i).velocity(1) = Utility.randIR(velRange(1,1),velRange(2,1));
                obj.agents(i).velocity(2) = Utility.randIR(velRange(1,2),velRange(2,2));
            end
            
            obj.mapDivisions = false(SL.mapDivResolution);
            obj.mapDivSize = (SL.mapSize(2)-SL.mapSize(1))/SL.mapDivResolution;
        end
        
        % Save Function
        function obj = saveAgentData(obj)
            SL = obj.simLaw;
            numAgents = SL.numAgents;
            for i=1:numAgents
                obj.agents(i).saveData();
            end
        end
        
        % Step Function
        function obj = stepSimulation(obj, frame)
            SL = obj.simLaw;
            numAgents = SL.numAgents;   %Get total number of agents
            for i=1:numAgents
                if obj.agents(i).isAlive
                    currentAgent = obj.agents(i);
                    
                    if frame==1 || mod(frame,SL.neighborFrameSkip)==0
                        %Find localAgents
                        localAgents = obj.funcHandle_findNeighborhood(obj,i,SL);
                        currentAgent.neighbors = localAgents;
                    else
                        localAgents = currentAgent.neighbors;
                    end
                    
                    %Find thermal strength from ThermalMap
                    thermalStrength = obj.thermalMap.getStrength(currentAgent.position);
                    
                    %Update currentAgent
                    obj.funcHandle_agentControl(currentAgent,localAgents,thermalStrength,[0,0,0], SL);
                end
            end
            for i=1:numAgents % Must occur after the previous loop is finished
                if obj.agents(i).markedForDeath && obj.agents(i).isAlive
                    obj.agents(i).isAlive = false;
                    causeOfDeath = obj.agents(i).killCause;
                    if(causeOfDeath == "Collision")
                        obj.collisionDeaths = obj.collisionDeaths + 1;
                    elseif(causeOfDeath == "Ground")
                        obj.groundDeaths = obj.groundDeaths + 1;
                    end
                end
            end
        end
        
        % Render
        function obj = renderAgents(obj)
            SL = obj.simLaw;
            shownNeighbors = false;
            for i=1:SL.numAgents
                if(~shownNeighbors && (SL.showFixedRadius || SL.showNeighbors || SL.showRange || SL.showArrow || SL.showText) && obj.agents(i).isAlive)
                    shownNeighbors = true;
                    currentAgent = obj.agents(i);
                    obj.thisAgent = i;

                    %% Show Vision Radius
                    if(SL.showFixedRadius)
                        theta = linspace(currentAgent.heading-SL.fov/2,currentAgent.heading+SL.fov/2,20);
                        xCircle = SL.neighborRadius * cos(theta) + currentAgent.position(1);
                        yCircle = SL.neighborRadius * sin(theta) + currentAgent.position(2);

                        if(class(obj.lineCircle) == "double")
                            obj.lineCircle = line();
                        end
                        obj.lineCircle.XData = xCircle;
                        obj.lineCircle.YData = yCircle;
                        if ~currentAgent.isAlive
                            obj.lineCircle.Visible = 'off';
                        end
                    end

                    %% Show Lines to Neighbors
                    if(SL.showNeighbors)
                        localAgents = currentAgent.neighbors;
                        numLocalAgents = size(localAgents,2);
%                         theirVelZ = zeros(1,numLocalAgents);
%                         for nb = 1:numLocalAgents
%                             theirVelZ(nb) = localAgents(nb).savedVelocity(3);
%                         end
%                         theirRelVelZ = theirVelZ - currentAgent.savedVelocity(3);
%                         ascendCaringFactor = SL.cohesionAscensionMult*(1 - (currentAgent.savedPosition(3)/SL.agentCeiling));
%                         theirRelVelZ(theirRelVelZ > SL.cohesionAscensionMax) = SL.cohesionAscensionMax;
%                         weightCohesion = (theirRelVelZ - SL.cohesionAscensionIgnore)*(ascendCaringFactor-1)/(SL.cohesionAscensionMax - SL.cohesionAscensionIgnore) + 1;
%                         % Set weights of sinking/weakly thermalling agents to 1
%                         weightCohesion(theirRelVelZ <= SL.cohesionAscensionIgnore) = 1;
%                         weightCohesion = min(max(weightCohesion,0),100);
%                         normedWeight = weightCohesion/100;
%                         neighborColor = hsv2rgb([0.4,1,mean(normedWeight)]);
                        neighborColor = [0 0 0];
                        linePoints = zeros(2,2*numLocalAgents+1);
                        linePoints(1,1) = currentAgent.position(1);
                        linePoints(2,1) = currentAgent.position(2);
                        for j=1:numLocalAgents
                            linePoints(1,2*j) = localAgents(j).position(1);
                            linePoints(2,2*j) = localAgents(j).position(2);
                            linePoints(1,2*j+1) = currentAgent.position(1);
                            linePoints(2,2*j+1) = currentAgent.position(2);
                        end
                        
                        if(class(obj.lineNeighbors) == "double")
                            obj.lineNeighbors = line();
                        end
                        obj.lineNeighbors.Color = neighborColor;
                        obj.lineNeighbors.XData = linePoints(1,:);
                        obj.lineNeighbors.YData = linePoints(2,:);
                    end
                    
                    %% Show Flight Range
                    if(SL.showRange)
                        theta = linspace(0,2*pi,30);
                        xCircleRange = currentAgent.velocity(1)/currentAgent.vsink * currentAgent.position(3) * cos(theta) + currentAgent.position(1);
                        yCircleRange = currentAgent.velocity(1)/currentAgent.vsink * currentAgent.position(3) * sin(theta) + currentAgent.position(2);

                        if(class(obj.lineRange) == "double")
                            obj.lineRange = line();
                        end
                        if currentAgent.position(3) < 200 && currentAgent.isAlive
                            obj.lineRange.XData = xCircleRange;
                            obj.lineRange.YData = yCircleRange;
                            obj.lineRange.Color = [1,0,0];
                            obj.lineRange.Visible = 'on';
                        else
                            obj.lineRange.Visible = 'off';
                        end

                    end
                    
                    %% Show Acceleration Arrows...
                    if(SL.showArrow)
                        %% Calc Arrows
                        SepMatrix      = [cos(currentAgent.rulesDir(1)), -sin(currentAgent.rulesDir(1)); sin(currentAgent.rulesDir(1)), cos(currentAgent.rulesDir(1))];
                        CohMatrix      = [cos(currentAgent.rulesDir(2)), -sin(currentAgent.rulesDir(2)); sin(currentAgent.rulesDir(2)), cos(currentAgent.rulesDir(2))];
                        AliMatrix      = [cos(currentAgent.rulesDir(3)), -sin(currentAgent.rulesDir(3)); sin(currentAgent.rulesDir(3)), cos(currentAgent.rulesDir(3))];
                        MigMatrix      = [cos(currentAgent.rulesDir(4)), -sin(currentAgent.rulesDir(4)); sin(currentAgent.rulesDir(4)), cos(currentAgent.rulesDir(4))];
                        %WagMatrix      = [cos(currentAgent.rulesDir(5)), -sin(currentAgent.rulesDir(5)); sin(currentAgent.rulesDir(5)), cos(currentAgent.rulesDir(5))];

                        arrow = SL.Arrow;
                        arrow = arrow .* SL.renderScale .* 0.6;
                        scalingFactor = max(max(currentAgent.rulesMag),1);
                        Sarrow = (SepMatrix * arrow .* currentAgent.rulesMag(1) ./ scalingFactor)' + currentAgent.position(1:2);
                        Carrow = (CohMatrix * arrow .* currentAgent.rulesMag(2) ./ scalingFactor)' + currentAgent.position(1:2);
                        Aarrow = (AliMatrix * arrow .* currentAgent.rulesMag(3) ./ scalingFactor)' + currentAgent.position(1:2);
                        Marrow = (MigMatrix * arrow .* currentAgent.rulesMag(4) ./ scalingFactor)' + currentAgent.position(1:2);
                        %Warrow = (WagMatrix * arrow .* currentAgent.rulesMag(5) ./ scalingFactor)' + currentAgent.position(1:2);

                        %% Create Arrows
                        if(class(currentAgent.patchObj) == "double")
                            % obj.patchArr = patch('FaceColor',color);
                            obj.patchSep = patch('FaceColor',[1 1 0]); % Yellow
                            obj.patchCoh = patch('FaceColor',[1 0 1]); % Magenta
                            obj.patchAli = patch('FaceColor',[0 1 1]); % Cyan
                            obj.patchMig = patch('FaceColor',[1 1 1]); % White
                            %obj.patchWag = patch('FaceColor',[.5 .5 .5]); % Gray
                        end

                        %% Position Arrows
                        obj.patchSep.XData = Sarrow(:,1);
                        obj.patchCoh.XData = Carrow(:,1);
                        obj.patchAli.XData = Aarrow(:,1);
                        obj.patchMig.XData = Marrow(:,1);
                        %obj.patchWag.XData = Warrow(:,1);
        
                        obj.patchSep.YData = Sarrow(:,2);
                        obj.patchCoh.YData = Carrow(:,2);
                        obj.patchAli.YData = Aarrow(:,2);
                        obj.patchMig.YData = Marrow(:,2);
                        %obj.patchWag.YData = Warrow(:,2);

                    end
                    
                    %% Text Box
                    if(SL.showText)
                        thisPos = currentAgent.position;
                        posX = thisPos(1);
                        posY = thisPos(2);
                        posZ = thisPos(3);
                        textPos = sprintf("X: %+4.0fm\nY: %+4.0fm\nY: %+4.0fm\n",posX,posY,posZ);
                        % heading = currentAgent.heading;
                        headingDeg = mod(currentAgent.heading*180/pi,360);
                        bankAngle = currentAgent.bankAngle*180/pi;
                        textAng = sprintf("Heading: %3.0fdeg\nBank: %+2.0fdeg\n",headingDeg,bankAngle);
                        speed  = currentAgent.velocity(1);
                        omega  = currentAgent.velocity(2);
                        vspeed = currentAgent.velocity(3);
                        Range = -speed/currentAgent.vsink * posZ;
                        heightFactor = (1 - posZ/SL.agentCeiling)^SL.heightFactorPower;
                        textSpd = sprintf("Speed: %2.0fm/s\nOmega: %+2.0fdeg/s\nVSpeed: %+1.1fm/s\nRange: %6.0fm\nHeight Factor: %g\n",speed,omega,vspeed,Range,heightFactor);
                        ruleMag = currentAgent.rulesMag;
                        textRule = sprintf("S:%2.2g\nC:%2.2g\nA:%2.2g\nM:%2.2g\n",ruleMag(1:4));
                        clearance = currentAgent.clearance;
                        localAgents = currentAgent.neighbors;
                        numLocalAgents = size(localAgents,2);
                        textDet = sprintf("Clearance:%5.1f\nNeighbors:%2.0f\n",clearance,numLocalAgents);
                        textnHeader = sprintf("N  \x0394Z   Dist \x0394V_{z} \x0394V_{xy} CWeight\n");
                        
                        textStr = textPos + textAng + textSpd + textRule + textDet + textnHeader;
%                         currentAgent.neighborData = struct();
                        
                        if(SL.listNeighborData) && numLocalAgents > 0
                            nRelHeight = currentAgent.neighborData.relPosition(:,3);
                            nDist      = vecnorm(currentAgent.neighborData.relPosition,2,2);
                            ndVz       = currentAgent.neighborData.relVelocity(:,3);
                            ndV        = vecnorm(currentAgent.neighborData.relVelocity(:,1:2),2,2);
                            nWght      = currentAgent.neighborData.cWeight;
                            [nWght, ind] = sort(nWght,'descend');
                            nRelHeight = nRelHeight(ind);
                            nDist = nDist(ind);
                            ndVz = ndVz(ind);
                            ndV = ndV(ind);

                            for n = 1:numLocalAgents
                                textStr = textStr + sprintf("%2.0f %+5.0f %4.0f %+3.1f %2.0f %0.4f\n",n,nRelHeight(n),nDist(n),ndVz(n),ndV(n),nWght(n));
                            end
                        end
                        
                        if(class(obj.textAnnt) == "double")
                            obj.textAnnt = annotation('textbox');
                            obj.textAnnt.FontName = 'FixedWidth';
                            obj.textAnnt.BackgroundColor = [1 1 0];
                            obj.textAnnt.FaceAlpha = 0.75;
                            obj.textAnnt.String = textStr;
                            obj.textAnnt.Position = [0 1 0.1 0.3];
                            obj.textAnnt.FitBoxToText = 'on';
                            obj.textAnnt.Position(2) = 1 - obj.textAnnt.Position(4);
                            obj.textAnnt.FontSize = 10;
                        end
                        obj.textAnnt.String = textStr;

                    end
                end
                %% All Agents
                if ~SL.followAgent || (abs(obj.agents(i).position(1) - obj.agents(obj.thisAgent).position(1)) < SL.followRadius ...
                                    && abs(obj.agents(i).position(2) - obj.agents(obj.thisAgent).position(2)) < SL.followRadius)
                    obj.agents(i).render(obj);
                elseif(class(obj.agents(i).patchObj) ~= "double")
                    obj.agents(i).patchObj.Visible = 'off';
                end
            end
        end
        
        % Updated Update Data Function
        function obj = updateData(obj,step)
            SL = obj.simLaw;
            
            obj.Elapsed(1) =     floor(step*SL.dt/3600);
            obj.Elapsed(2) = mod(floor(step*SL.dt/60  ),60);
            obj.Elapsed(3) = mod(floor(step*SL.dt     ),60);

            obj.maxHeight = SL.agentFloor;
            obj.minHeight = SL.agentCeiling;
            obj.avgHeight = 0;
            obj.avgSpeed = 0;
            
            currentLiving = nnz([obj.agents.isAlive]);
            if obj.Living ~= currentLiving
                % if living is suddenly 39/40, update number 1 to whatever time it
                % is now.
                % if multiple agents die, update that number of elements.
                % Living should always be >= nnz of isAlive; isAlive updates first.
                obj.ToD((SL.numAgents - obj.Living + 1) : (SL.numAgents - currentLiving)) = obj.Elapsed(2) + 60*obj.Elapsed(1);
            end
            obj.Living = currentLiving;
            obj.flightTime = obj.flightTime + obj.Living * SL.dt;

            numAgentsUsingThermals = 0;
            for i=1:SL.numAgents
                currentAgent = obj.agents(i);
                if currentAgent.isAlive
                    % Check map exploration
                    if step==1 || mod(step,SL.mapDivFrameSkip)==0
                        xIndex = ceil((currentAgent.savedPosition(1)-SL.mapSize(1))/obj.mapDivSize);
                        yIndex = ceil((currentAgent.savedPosition(2)-SL.mapSize(1))/obj.mapDivSize);
                        if(xIndex > 0 && xIndex <= SL.mapDivResolution && yIndex > 0 && yIndex <= SL.mapDivResolution)
                            obj.mapDivisions(xIndex,yIndex) = true;
                        end
                    end
                    
                    currentHeight = currentAgent.savedPosition(3);
                    if(currentHeight > obj.maxHeight)
                        obj.maxHeight = currentHeight;
                    end
                    if(currentHeight < obj.minHeight)
                        obj.minHeight = currentHeight;
                    end
                    obj.avgHeight = obj.avgHeight + currentHeight;
                    obj.avgSpeed = obj.avgSpeed + currentAgent.savedVelocity(1);
                    obj.heightScore = obj.heightScore + currentHeight * SL.dt;
                    
                    if(currentAgent.savedVelocity(3) > 0)
                        numAgentsUsingThermals = numAgentsUsingThermals + 1;
                    end
                end
            end
            % THIS
            % obj.avgHeight = obj.avgHeight / SL.numAgents;
            % obj.avgSpeed = obj.avgSpeed / SL.numAgents;
            % OR THIS
            obj.avgHeight = obj.avgHeight / obj.Living;
            obj.avgSpeed = obj.avgSpeed / obj.Living;
            
            obj.thermalUseScore = obj.thermalUseScore + numAgentsUsingThermals * SL.dt;
            obj.explorationPercent = 100 * sum(obj.mapDivisions(:))/SL.mapDivResolution^2;
        end
        
        % Render EVERYTHING
        function renderAll(obj)
%             obj.thermalMap = thermalMap;
            SL = obj.simLaw;
            hold on
    %         stringTitle = sprintf("Agents Alive: %g\nMax Height: %.1f\nMin Height: %.1f\nAverage Height: %.1f",Living,maxHeight,minHeight,averageHeight);
    %         stringTitle = sprintf("Minutes: %g\nAgents Alive: %g\nAverage Height: %.1f",minutes,Living,averageHeight);
            stringTitle = sprintf("Number %g, T+%01g:%02g:%02g, Score = %5.0fs\nLiving: %g  Avg: %.0f Min: %.0f Max: %.0f", ...
                obj.number, obj.Elapsed(1), obj.Elapsed(2), obj.Elapsed(3),obj.flightTime, obj.Living, obj.avgHeight, obj.minHeight, obj.maxHeight);
            title(stringTitle);
            obj.thermalMap.renderThermals();
            obj.renderAgents();

            if(SL.showText)
                obj.ax(1).Position = [0.2 0.15 0.7 0.7];
            else
                obj.ax(1).Position = [0.1 0.1 0.8 0.8];
            end
            if SL.followAgent
                 xlim([obj.agents(obj.thisAgent).position(1) - SL.followRadius, obj.agents(obj.thisAgent).position(1) + SL.followRadius]);
                 ylim([obj.agents(obj.thisAgent).position(2) - SL.followRadius, obj.agents(obj.thisAgent).position(2) + SL.followRadius]);
            else
                xlim(SL.mapSize);
                ylim(SL.mapSize);
            end
            obj.ax(1).PositionConstraint = 'outerposition';
            
            linkprop(obj.ax, {'XLim', 'YLim', 'ZLim', 'Position', 'View'});
            obj.colorbars(2).Position(2:4) = obj.colorbars(1).Position(2:4);
            if(SL.resolutionDPI == -1)
                currFrame = getframe(obj.simFig);
            else
                cdata = print(obj.simFig,'-RGBImage',sprintf("-r%g",SL.resolutionDPI));
                currFrame = im2frame(cdata);
            end
            writeVideo(obj.video,currFrame);
            pause(0.0001);
            hold off
        end

        % Initialize Video
        function obj = initVideo(obj,videoName)
            
            SL = obj.simLaw;
            obj.video = VideoWriter(videoName);
            obj.video.FrameRate = 1/SL.dt * SL.fpsMult / SL.frameSkip;
            open(obj.video);
            obj.simFig = figure('Visible',SL.Show);
            obj.simFig.Position = [0 0 1024 768];
            if(~isfield(SL,"resolutionDPI") || isnan(SL.resolutionDPI))
                SL.resolutionDPI = -1;
            end
            % Initialize map background
            clf
            xlim(SL.mapSize);
            ylim(SL.mapSize);
            daspect([1 1 1]);
            
            axa = gca;
            axa(2) = copyobj(axa, axa.Parent);
            linkprop(axa, {'XLim', 'YLim', 'ZLim', 'Position', 'View'});
            set(axa(2), 'Color', 'None', 'XColor', 'none', 'YColor', 'none', 'ZColor', 'none');
            
            c(1) = colorbar(axa(1));
            c(1).Location = 'eastoutside';
            cbLimits = [-1,SL.thermalStrengthMax];
            % colors = [6 42 127; 41 76 247; 102 59 231; 162 41 216; 222 24 200; 255 192 203] / 255;
            % x = 0:obj.thermalMap.thermalPixels/(length(colors)-1):obj.thermalMap.thermalPixels;
            % map = interp1(x/obj.thermalMap.thermalPixels,colors,linspace(0,1,obj.thermalMap.thermalPixels)); % Creates a color gradient for the map
            colormap(); %map);
            set(axa(1),'clim',cbLimits);
            axa(1).FontSize = 12;
            c(1).FontSize = 12;
            c(1).Title.String = "Updraft Speed [m/s]";
            c(1).Title.Rotation = 90;
            c(1).Title.HorizontalAlignment = 'center';
            c(1).Title.VerticalAlignment = 'middle';
            c(1).Title.Units = 'normalized';
            c(1).Title.Position = [2.4, 0.5, 0];
            c(1).Title.FontSize = 12;
            c(1).Title.FontName = "Arial";
            c(1).Title.Color = [0.1,0.1,0.1];
            
            c(2) = colorbar(axa(2));
            c(2).Location = 'eastoutside';
            set(axa(2),'clim',[SL.agentFloor,SL.agentCeiling]);
            %c(2).Ticks = [SL.agentFloor:500:(SL.agentCeiling-500),SL.agentCeiling];
            c(2).Ticks = SL.agentFloor:(SL.agentCeiling-SL.agentFloor)/5:SL.agentCeiling;
            c(2).TickLabels = {c(2).Ticks};
            set(axa(2),'Colormap',hsv2rgb([(0:0.8/255:0.8)',ones(256,2)]));
            c(2).Position(1) = 0.91;
            c(2).FontSize = 12;
            c(2).Title.String = "Agent Height [m]";
            c(2).Title.Rotation = 90;
            c(2).Title.HorizontalAlignment = 'center';
            c(2).Title.VerticalAlignment = 'middle';
            c(2).Title.Units = 'normalized';
            c(2).Title.Position = [3.6, 0.5, 0];
            c(2).Title.FontSize = 12;
            c(2).Title.FontName = "Arial";
            c(2).Title.Color = [0.1,0.1,0.1];
            
            obj.ax = axa;
            obj.colorbars = c;
            obj.simLaw = SL;
        end
        
        % Close Video
        function closeVideo(obj)
            close(obj.video);
        end
    end
end