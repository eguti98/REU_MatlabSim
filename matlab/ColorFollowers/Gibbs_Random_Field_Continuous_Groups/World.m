classdef World < handle % handle to make objects callable by reference
    
    %properties to hold handles need to be initiated in the way below
    properties (Access = public)
        max_x;
        max_y;
        draw_map %2D matrix for drawing
        num_robots;
        robot_list = Robot.empty;%Holds all our robot objects
        timeStep;
        spawnType;
        
        
    end
    
    methods (Access = public)
        function obj = World(timeStep, worldSize, spawnType, num_robots)
           %Constructor, make a new world and set up the object's variables
           %file_name is the name of the file holding the bitmap of the obstacle layer of the world
           disp("Building World!");
           
           obj.timeStep = timeStep;
           obj.max_x = worldSize;
           obj.max_y = worldSize;
           obj.spawnType = spawnType;
           obj.num_robots = num_robots;
        end

        function gen_bots(obj)
           %Create a list of our robots with default values of zero
           %each robot will get a copy of the world map.
           disp("Generating bots!");
           neededBots = obj.num_robots - length(obj.robot_list);
           switch obj.spawnType
               case 'random'
                   prevLength = length(obj.robot_list);
                   for w=1:neededBots %set up each robot object with a ID and a map object
                       i = prevLength + w;
                       obj.robot_list = [obj.robot_list; Robot(i,randi(obj.max_x-1),randi(obj.max_y-1),obj.timeStep)];
                       type = 'random';
                       obj.robot_list(i,1).newGoal(obj, type);
                   end
               case 'singleCoordinated'
                   prevLength = length(obj.robot_list);
                   for w=1:neededBots %set up each robot object with a ID and a map object
                       i = prevLength + w;
                       obj.robot_list = [obj.robot_list; Robot(i,randi(round(obj.max_x/4)),randi(round(obj.max_y/4)),obj.timeStep)];
                       type = 'topRight';
                       obj.robot_list(i,1).newGoal(obj, type);
                   end
               case 'doubleCoordinated'
                   if neededBots <= 25
                      return;
                   end
                   prevLength = length(obj.robot_list);
                   for w=1:neededBots %set up each robot object with a ID and a map object
                       i = prevLength + w;
                       if rand() > 0.5
                           obj.robot_list = [obj.robot_list; Robot(i,randi(round(obj.max_x/4)),randi(round(obj.max_y/4)),obj.timeStep)];
                           type = 'topRight';
                           obj.robot_list(i,1).newGoal(obj, type);
                       else
                           obj.robot_list = [obj.robot_list; Robot(i,randi([round(obj.max_x*3/4),obj.max_x]),...
                               randi(round(obj.max_y/4)),obj.timeStep)];
                           type = 'topLeft';
                           obj.robot_list(i,1).newGoal(obj, type);
                       end
                   end
               for i = 1:length(obj.robot_list)
                  obj.robot_list(i).id = i; 
               end
           end
        end
        
        function drawWorld(obj)
            figure(1)
            clf
            hold on
            for i = 1:length(obj.robot_list)
                xlim([0,obj.max_x+1]);
                ylim([0,obj.max_y+1]);
                RGB = obj.robot_list(i).RGB;
                %RGB = RGB/256;
                plot(obj.robot_list(i).truex, obj.robot_list(i).truey, '.', 'MarkerEdge', RGB, 'MarkerSize', 25);
                set(gca,'Color','k');
            end
            hold off
        end
        
        function tick(obj)
            disp("num_robots " + obj.num_robots);
            for ii = 1:length(obj.robot_list) %make each robot bust a move
                obj.robot_list(ii).move(obj);
                obj.robot_list(ii).FindNewColor;
                if obj.robot_list(ii).CheckGoalAllowance()
                    %obj.robot_list(ii).newGoal(obj, type);
                    obj.robot_list(ii) = [];
                    obj.gen_bots();
                end
                if ii+1 > length(obj.robot_list)
                   break; 
                end
            end
            obj.drawWorld();
        end 
    end
end

