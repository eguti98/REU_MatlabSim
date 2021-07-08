classdef Boid
    
    properties
        ID
        
        position  %my dead reckoning
        velocity
        acceleration
        covariance
        
        r
        max_force
        max_speed
        Ks
        Ka
        Kc
        Kh
        Kg
        path
        laser
        bearing
        particles
        color_particles
        neighbors
        detection_range
        
        mean_position  %estimated from covariance intersection
        mean_covar
        
        
        home
        goal
        found_goal
        is_beacon
        time_as_beacon
        
        sigmaVelocity
        sigmaYawRate
        biasVelocity
        biasYawRate
        
        t_position  %truth 
        t_velocity
        t_path        
        
    end
    
    methods
        function obj = Boid(position_x,  position_y, Ks, Ka,Kc, numBoids, ID)
            obj.ID = ID;
            obj.acceleration = [0 0];
            
            angle = (2*pi).*rand;
            obj.velocity = [cos(angle), sin(angle)];
            obj.t_velocity = obj.velocity;
            
            obj.position = [position_x, position_y];
            obj.t_position = obj.position;
            obj.r = 0;
            obj.max_speed = 2;
            obj.max_force = 0.1;
            
            obj.Ks = Ks;
            obj.Ka = Ka;
            obj.Kc = Kc;
            obj.Kh = 1;
            obj.Kg = 0;
            obj.found_goal = 1;
            
            
            obj.path = [position_x, position_y, obj.velocity(1), obj.velocity(2),0];
            obj.t_path =  obj.path;
            obj.laser = zeros(1,numBoids);
            obj.particles = cell(2,1);
            obj.particles{1} = zeros(3,numBoids);
            obj.particles{2} = zeros(2,2,numBoids);
            
            obj.color_particles = zeros(1,3);
            obj.time_as_beacon = 0;
            obj.is_beacon = 0;
        end
        
        
        function obj = apply_force(obj, sep_force, coh_force,  ali_force)
            home_force = obj.seek(obj.home);
            if obj.found_goal == 1
                obj.Kg = 0;
            end
            goal_force = obj.seek(obj.goal);
            obj.velocity = sep_force+coh_force+ali_force+obj.Kh*home_force+ obj.Kg*goal_force;
        end
        
        
        function obj = flock(obj,boids)
            sep = obj.seperate(boids);
            ali = obj.align(boids);
            coh = obj.cohesion(boids);
            
            sep = sep.*obj.Ks;%15;
            ali = ali.*obj.Ka;%1.0;
            coh = coh.*obj.Kc;%1.0;
            
            obj=obj.apply_force(sep,coh,ali);
        end
        
        function obj = borders(obj, lattice_size)
            if obj.position(1) < -obj.r
                obj.position(1)=lattice_size(1)+obj.r;
            end
            
            if obj.position(2) < -obj.r
                obj.position(2)=lattice_size(2)+obj.r;
            end
            
            if obj.position(1) > lattice_size(1) + obj.r
                obj.position(1)=-obj.r;
            end
            
            if obj.position(2) > lattice_size(2) + obj.r
                obj.position(2)=-obj.r;
            end
        end
        
        function obj = update(obj, noise)
            vel_old = obj.velocity;
            obj.velocity = obj.velocity + obj.acceleration;
            obj.velocity = obj.velocity./norm(obj.velocity).*obj.max_speed;
            if obj.is_beacon == 1 && rand > obj.time_as_beacon/100
               obj.velocity = [0,0]; 
            elseif obj.is_beacon == 1
                obj.is_beacon = 0;
            end
            obj.position = obj.position + obj.velocity;
            obj.acceleration = [0 0];
            
            
            obj.path = [obj.path;[obj.position + obj.velocity, obj.velocity./norm(obj.velocity).*obj.max_speed, omega]];
            obj.particles{1}(1,:) = obj.particles{1}(1,:) + obj.velocity(1);
            obj.particles{1}(2,:) = obj.particles{1}(2,:) + obj.velocity(2);
            
            if norm(obj.mean_position - obj.goal) < obj.detection_range
                %obj.goal = obj.home;
                obj.found_goal = 1;
            end
            
        end
        
        function [steer] = seek(obj, target)
            desired = target - obj.position;
            %desired = desired/norm(desired);
            desired = desired*obj.max_speed;
            
            steer = desired-obj.velocity;
            steer = steer.*obj.max_force;
        end
        
        function [steer] = seperate(obj, boids)
            desired_separation = obj.detection_range; %%%%%%%%%% communication range
            steer = [0,0];
            count = 0;
            positions = zeros(2,length(boids));
            for i=1:1:length(boids)
                positions(:,i) = boids(i).position;
            end
            d = pdist([obj.position; positions']);
            d = d(1:length(boids));
            
            for i=1:1:length(boids)
                if d(i) > 0 && d(i) <  desired_separation
                    difference = obj.position - boids(i).position;
                    difference = difference./norm(difference);
                    difference = difference./d(i);
                    steer = steer + difference;
                    count = count+1;
                end
                
                if count > 0
                    steer = steer./count;
                end
                
                if norm(steer) > 0
                    steer = steer./norm(steer).*obj.max_speed;
                    steer = steer - obj.velocity;
                    steer = steer./norm(steer).*obj.max_force;
                end
            end
        end
        
        function steer = align(obj, boids)
            neighbor_dist = obj.detection_range;
            sum = [0 0];
            count = 0;
            steer = [0 0];
            
            positions = zeros(2,length(boids));
            for i=1:1:length(boids)
                positions(:,i) = boids(i).position;
            end
            d = pdist([obj.position; positions']);
            d = d(1:length(boids));
            
            for i=1:1:length(boids)
                if d(i)>0 && d(i) < neighbor_dist
                    sum=sum+boids(i).position;
                    count=count+1;
                end
            end
            
            if count > 0
                sum=sum./count;
                sum=sum./norm(sum).*obj.max_speed;
                steer=sum-obj.velocity;
                steer=steer./norm(steer).*obj.max_force;
            end
        end
        
        function steer = cohesion(obj, boids)
            neighbor_dist = 50;
            sum = [0 0];
            count = 0;
            steer = [0 0];
            
            positions = zeros(2,length(boids));
            for i=1:1:length(boids)
                positions(:,i) = boids(i).position;
            end
            d = pdist([obj.position; positions']);
            d = d(1:length(boids));
            
            for i=1:1:length(boids)
                if d(i)>0 && d(i) < neighbor_dist
                    sum=sum+boids(i).position;
                    count=count+1;
                end
            end
            
            if count > 0
                sum=sum./count;
                steer = obj.seek(sum);
            end
        end
        
        function [obj, other] = trade_color(obj, other)
            %calculate probability weights
            W = other.color_particles./ sum(other.color_particles);
           
            %check to make sure the other agent has a
            %particle
            if sum(W) > 0
                color = randsample(1:3,1,true,W); %pick color particle
                obj.color_particles(color) = obj.color_particles(color)+1; %recieve particle
                other.color_particles(color) = other.color_particles(color)-1; %remove particle from other agent
            end
        end
        
    end
end
