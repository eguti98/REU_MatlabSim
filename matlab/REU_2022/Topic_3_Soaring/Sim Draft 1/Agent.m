% Agent class
classdef Agent < handle
    properties
        position = [0.0, 0.0, 0.0]      %m, [x,y,z]
        heading = 0.0                   %rad
        bankAngle = 0.0                 %rad
        velocity = [0.0, 0.0]           %m/s, rad/s, [forward,omega]
    end
    
    methods
        function obj = update(obj,localAgents,thermalStrength)
            %% Check other agents
            % cant do anything here until I know what localAgents looks like
            % enjoy fake functions
            %% Get Centroid
            Centroid = positionOfAgent;
            for i = 1:size(localAgents)
                if altitude(i) <= 0
                    continue;
                end
                Centroid = Centroid + position(i)*isnear(Agent, other, NaN);
            end
    
            distToCentroid = getDistanceToCentroid();
            NearAgent = nearestAgent();
            distToNearest = isnear(Agent, nearest, NaN);
            
            %% Get Accel
            accelMag_separation = separation * -1/distToNearest^2; %Negative, to go AWAY from the other
            accelMag_cohesion   = cohesion   *    distToCentroid^2; %Positive, to go TOWARDS the other
            accelMag_alignment  = alignment  *  1/distToNearest^2;
            accelMag_migration  = migration  *    1e-6*distToTarget^6;
        
            accel = accelMag_separation * diffUnit + ...
                    accelMag_cohesion   * diffUnit + ...
                    accelMag_alignment  * otherVelUnit + ...
                    accelMag_migration  * targetUnit; % nets accel vector to add on to current accel
            
            newAccel = newAccel + accel;
    
            forwardUnit = [cos(agentTheta);sin(agentTheta)];
            newAccel_forward = dot(newAccel,forwardUnit);
            newAccel_circ = 1.0 * sqrt((norm(newAccel))^2-newAccel_forward^2);
            newAccel3D = [newAccel(1),newAccel(2),0];
            forwardUnit3D = [forwardUnit(1),forwardUnit(2),0];
            
            turningCrossProduct = cross(forwardUnit3D,newAccel3D);
            newAccel_circ = newAccel_circ * sign(turningCrossProduct(3));

            newAccel = [newAccel_forward; newAccel_circ];

            if(norm(newAccel(1)) > maxForwardAccel)
               newAccel(1) = sign(newAccel(1)) * maxForwardAccel; 
            end

            %% Get Vel
            newVel(1) = agentVel(1) + newAccel(1)*dt;
            if(newVel(1) > maxForwardVel)
                newVel(1) = maxForwardVel;
            elseif(newVel(1) < minForwardVel)
                newVel(1) = minForwardVel;
            end
            % v^2/r = a
            newVel(2) = newAccel(2)/newVel(1);
            if(norm(newVel(2)) > maxOmega)
                newVel(2) = sign(newVel(2)) * maxOmega;
                newAccel(2) = newVel(1)*newVel(2);
            end
            obj.bankAngle = atan(newAccel(2)/g);

            vsink = (simLaw.Sink_A*newVel(1).^2 + simLaw.Sink_B*newVel(1) + simLaw.Sink_C)...
                    / sqrt(cos(obj.bankAngle));
            vspeed = vsink + thermalStrength;

            %% Get Pos
            newPos = agentPos + newVel(1)*forwardUnit*dt;
            newTheta = agentTheta + newVel(2)*dt;
            newPos(4) = agentAlti + vspeed*dt;
            % giga jank
            
            if norm([newPos(1),newPos(2)]) < thermal(3)/2 && newPos(4) < thermal(5)
                newPos(4) = newPos(4) + thermal(4)*dt;
            end

        end
        
        function render(obj)
            rotationMatrix = [cos(obj.heading), -sin(obj.heading); sin(obj.heading), cos(obj.heading)];
            rotatedShape = rotationMatrix * SimLaw.agentShape_plane; %[x;y] matrix
            rotatedShape = rotatedShape'; %Convert to [x,y];
            globalShape = rotatedShape + obj.position(1:2); %[x,y] matrix
            
            patch(globalShape(:,1),globalShape(:,2),'k'); 
        end
    end
end