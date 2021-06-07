classdef Swarmbot
    %UNTITLED Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        
        %% enviorment sensors
        velocity % [Vx, Vy, omega]  comes from wheel odometry
        lidar % multiRobotLidarSensor object
        neighbors  %list of neighboring robot objects
        id %unique robot identifier
        
        truePose % [x,y,theta] our true location in the world (only for debugging)
        truePath % [X,Y, THETA] our true path taken in the world (only for debugging)
       
        %% internal sensors
        battery % scalar battery level of robot
        time    % amount of time that has passed 
        money  % scalar amount of money to spend
        food  % scalar amount of food in the robot's inventory
        isInvader %determines if this is an invader robot
        
        %% long term memory
        position % [x; y; theta] estimated from localization
        Gmap %global grid map
        Lmap % local grid of objects
        path % [X; Y; Z] collections of past locations, horizontal axis is time
        
        
    end
    
    methods
        
%% #################################################  FUNDAMENTAL FUNCTIONS
        function obj = Swarmbot(ID)
            %Swarmbot Construct an instance of this class
  
            %give the robot and id
            obj.id = ID;
        end
 %----------------------------------------------------------------- 
        function obj = getSensorData(obj, vel, ranges, neighbors)
            %recieves a MultiRobotEnv object and updates the sensor
            %readings
            obj.velocity = vel;
            
            scanAngles = linspace(-pi,pi,length(ranges))';
            obj.lidar = [scanAngles, ranges];
            
            obj.neighbors = neighbors; 
        end
 %----------------------------------------------------------------      
        function act = actOnEnv(obj)
            % the robots "message" to the enviorment, and the total sum of
            % all the individual messages that could be placed on or picked
            % up from the enviorment, add new information as a struct
            
            % set desired Velocity
            act = struct ("velocity", obj.velocity);
            % TODO: add / remove food from enviorment
            
             
        end
 %------------------------------------------------------------------------    
         function message = transfer(obj, Robot)
            % the robots "message" to another robot, and the total sum of
            % all the individual messages that could be sent add them as
            % parts of the struct of the message
            
            message = struct("food",0 , "money", 0,  "position", obj.pose, "velocity", obj.velocity);
            
            
        end
        
 %% ################################################## Navigation functions
 
 %% ######################################################## ObAv functions
 
 %% ############################################# Invader Defense Functions
 
 %% ########################################### Coop-Localization Functions      
        
    end
end

