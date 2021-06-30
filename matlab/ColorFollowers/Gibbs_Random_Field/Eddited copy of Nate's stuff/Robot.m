classdef Robot < handle
    %ROBOT Summary of this class goes here
    %One robot object for each simulated robot. The robot decides how it
    %will move and returns it's actions to the owning class.
    properties
        id = 0;
        x = 1;
        y = 1;
        truex = 1;
        truey = 1;
        Vx = 0;
        Vy = 0;
        color;
        VMax = 1.5;
        sigma = 0.4;
        
        %All just random values for now, need to be tuned
        %------------------------------------------------
        charge = 4;
        obs_charge = 4;
        epsilon = 0.04;
        epsilon_not = 0.04;
        alpha = 1;
        r_not = 5;
        mass = 0.5;
        %------------------------------------------------
        
        local_map;
        neighborList;
        sensingRange = 5;
        timeStep;
    end
    
    methods
        function obj = Robot(id,x,y, ts, col, map_in)
            %ROBOT Construct an instance of this class
            obj.x = x; %init x coord
            obj.y = y;
            obj.truex = x;
            obj.truey = y;
            obj.id = id; %A unique ID for the robot
            obj.color = col;
            
            obj.local_map = map_in;
            obj.timeStep = ts;
        end
        
        
        function xy = get_xy(obj)
            %Returns a tuple of the robots present X and Y coords
            xy = [obj.x,obj.y];
        end

        %This takes the newVelocity output by the grf method and uses it to
        %find the next square to go to, considering walls and other agents
        %but not obstacles yet
        function xy = move(obj, worldObj)
            obj.getNeighbors(worldObj);
            newVelocity = MetropolisHastings(obj, worldObj);
            obj.Vx = newVelocity(1);
            obj.Vy = newVelocity(2);
            
            [obj.truex, obj.truey] = obj.kinematicModel(newVelocity);
            obj.x = round(obj.truex);
            obj.y = round(obj.truey);
            if obj.x < 1
                obj.x = 1;
                obj.truex = 1;
                obj.Vx = 0;
                obj.Vy = 0;
            end
            if obj.y < 1
                obj.y = 1;
                obj.truey = 1;
                obj.Vx = 0;
                obj.Vy = 0;
            end
            if obj.x > worldObj.max_x
                obj.x = worldObj.max_x;
                obj.truex = worldObj.max_x;
                obj.Vx = 0;
                obj.Vy = 0;
            end
            if obj.y > worldObj.max_y
                obj.y = worldObj.max_y;
                obj.truey = worldObj.max_y;
                obj.Vx = 0;
                obj.Vy = 0;
            end
            xy = [obj.x,obj.y];
        end
        
        %This function find the indexes of all the neighbors of the central
        %agent and puts them in neighborList
        function getNeighbors(obj, worldObj)
            obj.neighborList = [];
            for i = obj.x-obj.sensingRange:obj.x+obj.sensingRange
                for j = obj.y-obj.sensingRange:obj.y+obj.sensingRange
                    if i > 0 && i < worldObj.max_x && j > 0 && j < worldObj.max_y
                        if worldObj.worldMap.map(i,j,worldObj.robot_layer) ~= 0
                            obj.neighborList(length(obj.neighborList)+1) = worldObj.worldMap.map(i,j,worldObj.robot_layer);
                        end
                    end
                end
            end
        end
        
        %Very Basic Kinematic Model
        function [x,y] = kinematicModel(obj, propVel)
            x = obj.truex + propVel(1) * obj.timeStep;
            y = obj.truey + propVel(2) * obj.timeStep;
        end
        
        %This function finds the sum of all the coulomb buckingham
        %potentials for all the neighbors for a given proposed velocity as
        %well as the CB potential from the static obstacles
        function [CBPotential, OAPotential] = coulombBuckinghamPotential(obj, worldObj, propVel)
            CBPotential = 0;
            [propX, propY] = obj.kinematicModel(propVel);
            
            for i = 1:length(obj.neighborList)
                neighborRobot = worldObj.robot_list(obj.neighborList(i));
                [neighX, neighY] = neighborRobot.kinematicModel([neighborRobot.Vx, neighborRobot.Vy]);
                radius = sqrt((propX-neighX)^2 + (propY-neighY)^2);
                
                if obj.color == neighborRobot.color
                    chargeProduct = -abs(obj.charge*neighborRobot.charge);
                else
                    chargeProduct =  abs(obj.charge*neighborRobot.charge);
                end
                
                CBPotential = CBPotential + (obj.epsilon * (6/(obj.alpha - 6) * exp(obj.alpha)...
                    * (1 - radius/obj.r_not) - obj.alpha/(obj.alpha - 6) * (obj.r_not/radius)^6)...
                    + chargeProduct/(4*pi*obj.epsilon_not*radius));
            end
            
            closeObstacles = obj.ObstacleAvoidingPotential(worldObj, propVel);
            OAPotential = 0;
            for i = 1:length(closeObstacles)
                radius = norm([propX, propY] - closeObstacles(i,:));
                chargeProduct = abs(obj.charge * obj.obs_charge);
                OAPotential = OAPotential + (obj.epsilon * (6/(obj.alpha - 6) * exp(obj.alpha)...
                    * (1 - radius/obj.r_not) - obj.alpha/(obj.alpha - 6) * (obj.r_not/radius)^6)...
                    + chargeProduct/(4*pi*obj.epsilon_not*radius));
            end
        end
        
        %This function finds the Kinetic Energy potential imposed by the
        %neighbors as well as the KE potential imposed by the self
        function [KENeighbor, KESelf] = KineticEnergyPotential(obj, worldObj, propVel)
            neighborObjList = worldObj.robot_list(obj.neighborList);
            
            VxSum = 0;
            VySum = 0;
            group_mass = 0;
            for i = 1:length(neighborObjList)
                if neighborObjList(i).color == obj.color
                    VxSum = VxSum + (neighborObjList(i).Vx - obj.Vx);
                    VySum = VySum + (neighborObjList(i).Vy - obj.Vy);
                    group_mass = group_mass + neighborObjList(i).mass;
                end
            end
            
            KENeighbor = 0.5 * group_mass * (VxSum^2 + VySum^2);
            KESelf = 0.5 * obj.mass * norm(obj.VMax - propVel)^2;
        end
        
        %This function find the list of obstacles that are close to the
        %central agent for use in the Coulomb buckingham function
        function closeObstacles = ObstacleAvoidingPotential(obj, worldObj, propVel)
            [obsXs, obsYs] = find(worldObj.worldMap.map(:,:,worldObj.obs_layer));
            obstacleLocations = [obsXs, obsYs];
            [propX,propY] = obj.kinematicModel(propVel);
            distToObstacles = vecnorm([obsXs, obsYs] - [propX,propY],2,2);
            closeObstacles = obstacleLocations(distToObstacles <= obj.sensingRange);
        end
        
        %This function calculates the probability of a given proposed
        %velocity given the potential functions and the agents around the
        %central agent
        function newVelocity = MetropolisHastings(obj, worldObj)
            mcmcChain = [obj.Vx, obj.Vy];
            [KENeighbor, KESelf] = obj.KineticEnergyPotential(worldObj, mcmcChain(1,:));
            [CBPotential, OAPotential] = obj.coulombBuckinghamPotential(worldObj, mcmcChain(1,:));
            potentialChain = KENeighbor + KESelf + CBPotential + OAPotential;
            
            for i = 1:20
               
                propVx = normrnd(obj.Vx, obj.sigma);
                propVy = normrnd(obj.Vy, obj.sigma);
                [KENeighbor, KESelf] = obj.KineticEnergyPotential(worldObj, [propVx,propVy]);
                [CBPotential, OAPotential] = obj.coulombBuckinghamPotential(worldObj, [propVx,propVy]);
                newPotential = KENeighbor + KESelf + CBPotential + OAPotential;
                
                dE = newPotential - potentialChain(length(potentialChain));
                grf = exp(-dE);
                
                if dE < 0 || grf > rand(1)
                    mcmcChain(size(mcmcChain,1)+1, :) = [propVx, propVy];
                    potentialChain(length(potentialChain)+1) = newPotential;
                else
                     mcmcChain(size(mcmcChain,1)+1, :) = mcmcChain(size(mcmcChain,1),:);
                     potentialChain(length(potentialChain)+1) = potentialChain(length(potentialChain));
                end
            end
            
            mcmcChain(1:floor(length(mcmcChain)/2),:) = [];
            newVelocity(1,1) = mean(mcmcChain(:,1));
            newVelocity(1,2) = mean(mcmcChain(:,2));
            
            if norm(newVelocity) > obj.VMax
               newVelocity = newVelocity/norm(newVelocity)*obj.VMax; 
            end
        end
        
    end
end









