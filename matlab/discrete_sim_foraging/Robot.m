classdef Robot < handle
    %ROBOT Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        id = 0;
        x = 1;
        y = 1;
        wallet = 2;
        battery =3;
        last_heading =4;
        local_map = 'a'; %= World_Map("a")
    end
    
    methods
        function obj = Robot(id,x,y,wallet,battery,heading,map_in)
            %ROBOT Construct an instance of this class
%             if nargin > 0
%             obj.Value = v;
%             end
            obj.x = x; %init x coord
            obj.id = id; %A unique ID for the robot
            obj.y = y; %init y coord %%%CHANGE BACK!!!!!!!!
            obj.wallet = wallet; %init amount of money
            obj.battery = battery;
            if (heading == 0)
            obj.last_heading = randi([1,8]); %Start out with a random direction of travel
            else
                obj.last_heading = heading;
            end
            
            %obj.local_map = World_Map(map_in);
            obj.local_map = map_in;
            
        end
        
        %This will call other functions depending on if the robot should be
        %foraging, moving home, moving to trade, etc.
        function move_next()
            %Are we searching?
            %move_search();
            
            %Are we going home?
            %move_home();
        end
        
        function xy = get_xy(obj)
            xy = [obj.x,obj.y];
        end
        %TODO
        %Returns a handle to the object when called
        function val = get(obj)
            val = obj;
        end
        
        %check for if on food
        %use persistence
        %check for boundaries
        %move the robot in a random direction
        function xy = move(obj)
            disp("moving robot");
            temp_x = obj.x;
            temp_y = obj.y;
            dir = obj.last_heading + randi([-1,1]);
            dir = mod(dir,8);
            obj.last_heading = dir;
            disp(dir);
            
            if dir == 1
                obj.x = obj.x;
                obj.y = obj.y+1;
            elseif (dir == 2)
                obj.x = obj.x-1;
                obj.y = obj.y+1;
            elseif (dir == 3)
                obj.x = obj.x-1;
                obj.y = obj.y;
            elseif (dir == 4)
                obj.x = obj.x-1;
                obj.y = obj.y-1;
            elseif (dir == 5)
                obj.x = obj.x;
                obj.y = obj.y-1;
            elseif (dir == 6)
                obj.x = obj.x+1;
                obj.y = obj.y-1;
            elseif (dir == 7)
                obj.x = obj.x+1;
                obj.y = obj.y;
            elseif (dir == 8)
                obj.x = obj.x+1;
                obj.y = obj.y+1;
            end           
            
            %pick up food
%             if(obj.map(obj.robot_x, obj.robot_y, 2) >0)
%                 obj.map(obj.robot_x, obj.robot_y, 2) = 0;
%                 disp("Picked up food!");
%             end
            
            %Guard leaving map
            if(obj.x < 1)
                obj.x = 1;
            end
            if (obj.x > size(obj.local_map.map,1))
                obj.x = size(obj.local_map.map,1);
            end
            if(obj.y < 1)
                obj.y = 1;
            end

            %scan surrounding area
            disp("obj.x is " + obj.x);

            if(obj.local_map.map(obj.x, obj.y, 1) >0)
                obj.x = temp_x;
                obj.y = temp_y;
                disp("oopsy woopsy, I crashed!");
            end
           xy = [obj.x, obj.y];

        end
     end
end

