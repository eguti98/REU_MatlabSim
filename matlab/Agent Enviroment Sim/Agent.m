classdef Agent < handle
    %UNTITLED3 Summary of this class goes here
    %   Detailed explanation goes here
    
    properties (Access = public)
       pose;
       velocity;
       path; 
       pathColor;      
       goalPose;
       color = [1 1 1];
       measuredAgents = Agent.empty;
       measuringRange = 3;
    end
    
    properties (Access = private)  
        id;
        radius;
        controller;
    end
    
    methods
        function callMeasurement(obj, envObj) 
            disp = 0;
            envAgents = envObj.getNumberOfAgents; 
            obj.measuredAgents = Agent.empty;
            for i = 1:(envAgents-1)
                if obj.id + i >  envAgents
                    disp = envAgents;
                end
                if norm(envObj.agents(obj.id+i - disp).pose - obj.pose) < obj.measuringRange
                     obj.measuredAgents(end + 1) = envObj.agents(obj.id+i - disp);  
                end
            end
        end
        
        function obj = Agent(id, radius)
            obj.id = id;
            obj.radius = radius;
        end
    
        function radius = getRadius(obj)
            radius = obj.radius;
        end
        
        function unitVec = calcIdealUnitVec(obj)
            unitVec = (obj.goalPose - obj.pose)./ ...
                       vecnorm(obj.goalPose - obj.pose, 2, 2);
        end
        function callController(obj)
            obj.controller(obj);
        end
        
        function setController(obj,controller)
            obj.controller = controller;
        end
    end
end

