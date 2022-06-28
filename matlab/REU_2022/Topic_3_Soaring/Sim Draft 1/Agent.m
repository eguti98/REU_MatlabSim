% Agent class
classdef Agent < handle
    properties
        simLaw
        
        position = [0.0, 0.0, 0.0]      %m, [x,y,z]
        heading = 0.0                   %rad
        bankAngle = 0.0                 %rad
        velocity = [0.0, 0.0]           %m/s, rad/s, [forward,omega]
        patchObj = NaN
        patchArr = NaN
        isAlive  = true
        accelDir = 0.0;
        rulesDir = [0.0, 0.0, 0.0, 0.0] % S, C, A, M

        lastWaggle = 0;
        waggleSign = 0;
        
        savedPosition = [0.0, 0.0, 0.0]
        savedVelocity = [0.0, 0.0]
        savedHeading = 0.0
    end
    
    methods
        % Render Function (1/2)
        function obj = render(obj)
            SL = obj.simLaw;

            %% Calculate Agent Orientation Properties
            rotationMatrix = [cos(obj.heading), -sin(obj.heading); sin(obj.heading), cos(obj.heading)];
            shape = SL.agentShape_plane .* SL.renderScale;
            rotatedShape = rotationMatrix * shape; %[x;y] matrix
            rotatedShape = rotatedShape'; %Convert to [x,y];
            globalShape = rotatedShape + obj.position(1:2); %[x,y] matrix
            scaledAlti = 0.8*((obj.position(3)-SL.agentFloor)/(SL.agentCeiling - SL.agentFloor));
            % Fix altitude
            if scaledAlti < 0
                scaledAlti = 0;
            elseif scaledAlti > 0.8
                scaledAlti = 0.8;
            end
            color = hsv2rgb([scaledAlti,1,1]);
            %fprintf("hue: %g\n",color(1));
            
            %% Calculate Acceleration Direction
            if SL.showArrow
                

                AccelMatrix    = [cos(obj.accelDir), -sin(obj.accelDir); sin(obj.accelDir), cos(obj.accelDir)];
                SepMatrix      = [cos(obj.rulesDir(1)), -sin(obj.rulesDir(1)); sin(obj.rulesDir(1)), cos(obj.rulesDir(1))];
                CohMatrix      = [cos(obj.rulesDir(2)), -sin(obj.rulesDir(2)); sin(obj.rulesDir(2)), cos(obj.rulesDir(2))];
                AliMatrix      = [cos(obj.rulesDir(3)), -sin(obj.rulesDir(3)); sin(obj.rulesDir(3)), cos(obj.rulesDir(3))];
                MigMatrix      = [cos(obj.rulesDir(4)), -sin(obj.rulesDir(4)); sin(obj.rulesDir(4)), cos(obj.rulesDir(4))];
                
                arrow = SL.Arrow;
                arrow(1,:) = arrow(1,:) + 0.5;
                arrow = Arrow .* SL.renderScale;
                rotatedArrow = AccelMatrix * arrow;
                rotatedArrow = rotatedArrow';
                globalArrow = rotatedArrow + obj.position(1:2);

                Sarrow = SL.Arrow .* SL.renderScale;

            end
            
            %% Do Patch Functions
            if(class(obj.patchObj) == "double")
                if SL.showArrow
                    obj.patchArr = patch('FaceColor',color);
                end
                obj.patchObj = patch('FaceColor',color);
            end
            if SL.showArrow
                obj.patchArr.FaceColor = color;
                obj.patchArr.XData = globalArrow(:,1);
                obj.patchArr.YData = globalArrow(:,2);
            end
            obj.patchObj.FaceColor = color;
            obj.patchObj.XData = globalShape(:,1);
            obj.patchObj.YData = globalShape(:,2);
            if ~obj.isAlive
                obj.patchObj.Visible = 'off';
                if SL.showArrow
                    obj.patchArr.Visible = 'off';
                end
            end

        end
        
        % Save Function (2/2)
        function obj = saveData(obj)
            obj.savedPosition = obj.position;
            obj.savedVelocity = obj.velocity;
            obj.savedHeading = obj.heading;
        end
    end
end