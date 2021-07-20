classdef Robot
    
    properties
        %% class properties
        ID              % [int] id of the robot
        home            % [X, Y] home location of the robot
        goal            % [X, Y] goal location for the robot
        found_goal      % 0 = not found my current goal
        % 1 = found my current goal
        estimator       % 0 = dead_reckoning,
        % 1 = covariance intersection,
        % 2 = decentralized EKF
        % 3 = centralized EKF
        
        % positioning------------------------------------------------
        %dead reckoning
        position_d      % [X, Y, Yaw]
        velocity_d      % [Vx, Vy]
        covariance_d    % [3x3 X, Y, Yaw] covariance matrix
        path_d          % [X, Y, Yaw;   path taken by robot
        %  .., ..,..];
        
        %estimated localization
        position_e      % [X, Y, Yaw]
        velocity_e      % [Vx, Vy]
        covariance_e    % [3x3 X, Y, Yaw] covariance matrix
        path_e          % [X, Y, Yaw;   path taken by robot
        %  .., ..,..];
        
        %truth
        position_t      % [X, Y, Yaw]
        velocity_t      % [Vx, Vy]
        path_t          % [X, Y, Yaw;   path taken by robot
        %  .., ..,..];
        
        % sensors / measurment ----------------------------------------
        dt              % time step size
        vel_m           % velocity magnitude from wheel encoder
        yaw_rate_m      % yaw rate from wheel encoder
        laser           % [dist, dist, ...] lidar distances to every robot
        bearing         % [phi, phi, ...] global angle to every robot
        neighbors       % [robot.ID, robot.ID, ...] array of local robot's IDs
        state_particles % 2x1 cell array top cell holds state measurement of this robot from other robots
        %                lower cell holds covariances of the measurements
        
        detection_range % [double] detection range of the robot
        sigmaVelocity   % [double] wheel velocity variance
        biasVelocity    % [double] wheel velocity bias
        sigmaYawRate    % [double] wheel yaw rate variance
        biasYawRate     % [double] wheel yaw rate bias
        sigmaRange      % [double] lidar distance variance
        sigmaHeading    % [double] lidar angle variance
        
        %Boids parameters -------------------------------------------------
        
        acceleration    % [Ax, Ay] tell robot how to change its velocity
        max_force       % [double] limits maximum acceleration
        max_speed       % [double] velocity limit on the robot
        Ks              % [double] seperation gain
        Ka              % [double] alignment gain
        Kc              % [double] cohesion gain
        Kh              % [double] home gain
        Kg              % [double] goal gain
        
        % filtering variables --------------------------------------------
        X               % cell{ [X1; Y1; Yaw1], [X2,Y2,Yaw2], ...}
        % stores the estimated states of all the robots
        
        P               % cell{ [3x3 1.1], [3x3 1.2], [3x3] 1.3, ... ;
        %       [3x3 2.1], [3x3 2.2], [3x3] 2.3, ... ;
        %       [3x3 3.1], [3x3 3.2], [3x3] 3.3, ...;
        %        ...     ,   ...    ,    ...   , ... }
        % stores the [X, Y, Yaw] covariance matrix for each
        % robot and the cross covariances in the off
        % diagonals
        
        % assimilation colors ----------------------------------------------
        color_particles
        
        % beacon parameters----------------------------------------------
        is_beacon
        time_as_beacon
        
    end
    3
    methods
        
        function obj = Robot(position_x,  position_y, Ks, Ka,Kc, numBoids, ID)
            obj.ID = ID;
            obj.found_goal = 1;
            
            % give initialize position and velocity
            angle = (2*pi).*rand;
            obj.velocity_d = [cos(angle), sin(angle)];
            obj.velocity_t = obj.velocity_d;
            obj.velocity_e = obj.velocity_d;
            
            obj.position_d = [position_x, position_y, angle];
            obj.position_t = obj.position_d;
            obj.position_e = obj.position_d;
            
            obj.path_d = [position_x, position_y, angle];
            obj.path_t =  obj.path_d;
            obj.path_e = obj.path_d;%(1:2);
            
            % initalize boids parameters-------------------------------------------
            obj.max_speed = 5;
            obj.max_force = 5;%0.1;
            obj.acceleration = [0 0];
            
            obj.Ks = Ks;
            obj.Ka = Ka;
            obj.Kc = Kc;
            obj.Kh = 1;
            obj.Kg = 0;
            
            % initalize measurments ---------------------------------------
            
            obj.laser = zeros(1,numBoids);
            obj.bearing = obj.laser;
            obj.vel_m = norm(obj.velocity_t);
            obj.yaw_rate_m = 0;
            obj.state_particles = cell(2,1);
            
            
            % decentralized EKF parameters
            obj.X = cell (1,numBoids);
            obj.X{obj.ID} = obj.position_e';
            
            obj.P = cell(numBoids, numBoids);
            for i = 1:numBoids % For each robot
                for j = 1:numBoids % For each robot
                    if i == j
                        obj.P{i,j} = eye(3); % Covariance matrix
                    else
                        obj.P{i,j} = zeros(3); % Correlated matrix
                    end
                end
            end
            % color particle initalization
            obj.color_particles = zeros(1,3);
            
            % beacon initialization
            obj.time_as_beacon = 0;
            obj.is_beacon = 0;
            
            
        end
        
        %% BOIDS FUNCTIONS ------------------------------------------------
        
        function obj = boids_update(obj,e_max,rho_max)
            
            % measure local density
            A = pi*obj.detection_range^2;
            rho = length(obj.neighbors) / A;
            covar = obj.covariance_e;
            
            mean_error = norm(obj.position_d(1:2) - obj.position_e(1:2));
            % update boids parameters
            obj.max_speed = (norm(covar)+2)/(norm(obj.position_e(1:2)-obj.position_e(1:2))+1)^2;
            if obj.max_speed > 5
                obj.max_speed = 5;
            end
            obj.Ka = rho/rho_max + mean_error/e_max;
            obj.Kc = (norm(covar) + mean_error^2)/A; %norm([norm(robot.covariance), mean_error^2]);
            obj.Ks = A/(norm(covar) + mean_error^2);
            obj.Kh = (mean_error^2 + norm(covar))/(norm(obj.home-obj.position_e(1:2))^2);
            obj.Kg = obj.detection_range/(norm(obj.goal-obj.position_e(1:2))*norm(covar));
            
        end
        
        function obj = apply_force(obj,sep_force,coh_force,ali_force)
            home_force = obj.seek(obj.home);
            if obj.found_goal == 1
                obj.Kg = 0;
            end
            goal_force = obj.seek(obj.goal);
            force = sep_force+coh_force+ali_force+obj.Kh*home_force+ obj.Kg*goal_force;
            obj.acceleration = obj.max_force * force / norm(force);
            
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
        
        function [steer] = seek(obj,target)
            desired = target - obj.position_e(1:2);
            desired = desired/norm(desired);
            desired = desired*obj.max_speed;
            
            steer = desired-obj.velocity_e;
            steer = steer.*obj.max_force/norm(steer);
        end
        
        function [steer] = seperate(obj,boids)
            desired_separation = obj.detection_range; %%%%%%%%%% communication range
            steer = [0,0];
            count = 0;
            positions = zeros(2,length(boids));
            for i=1:1:length(boids)
                positions(:,i) = boids(i).position_e(1:2);
            end
            d = pdist([obj.position_e(1:2); positions']);
            d = d(1:length(boids));
            
            for i=1:1:length(boids)
                if d(i) > 0 && d(i) <  desired_separation
                    difference = obj.position_e(1:2) - boids(i).position_e(1:2);
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
                    steer = steer - obj.velocity_e;
                    steer = steer./norm(steer).*obj.max_force;
                end
            end
        end
        
        function steer = align(obj,boids)
            neighbor_dist = obj.detection_range;
            sum = [0 0];
            count = 0;
            steer = [0 0];
            
            positions = zeros(2,length(boids));
            for i=1:1:length(boids)
                positions(:,i) = boids(i).position_e(1:2);
            end
            d = pdist([obj.position_e(1:2); positions']);
            d = d(1:length(boids));
            
            for i=1:1:length(boids)
                if d(i)>0 && d(i) < neighbor_dist
                    sum=sum+boids(i).position_e(1:2);
                    count=count+1;
                end
            end
            
            if count > 0
                sum=sum./count;
                sum=sum./norm(sum).*obj.max_speed;
                steer=sum-obj.velocity_e;
                steer=steer./norm(steer).*obj.max_force;
            end
        end
        
        function steer = cohesion(obj,boids)
            neighbor_dist = 50;
            sum = [0 0];
            count = 0;
            steer = [0 0];
            
            positions = zeros(2,length(boids));
            for i=1:1:length(boids)
                positions(:,i) = boids(i).position_e(1:2);
            end
            d = pdist([obj.position_e(1:2); positions']);
            d = d(1:length(boids));
            
            for i=1:1:length(boids)
                if d(i)>0 && d(i) < neighbor_dist
                    sum=sum+boids(i).position_e(1:2);
                    count=count+1;
                end
            end
            
            if count > 0
                sum=sum./count;
                steer = obj.seek(sum);
            end
        end
        
        %% MEASUREMENTS ---------------------------------------------------
        
        function obj = lidar_measurement(obj,ROBOTS)
            
            dists = []; %distances to every robot
            angles = [];%global angle to every robot
            numBots = length(ROBOTS);
            r = obj.ID;  % this robot
            neigh = [];  % neighbor robot ID's
            
            for L = 1:numBots % other robot
                
                %distance from this robot (r) to other robot (L)
                d = norm(ROBOTS(L).position_t(1:2)- ROBOTS(r).position_t(1:2)); %truth
                d = d + normrnd(0,ROBOTS(r).sigmaRange,1,1); %noise
                %angle from r to L
                phi = atan2(ROBOTS(L).position_t(2)- ROBOTS(r).position_t(2), ROBOTS(L).position_t(1)- ROBOTS(r).position_t(1)); % truth
                phi = phi + normrnd(0,ROBOTS(r).sigmaHeading,1,1); %noise
                phi = phi + angdiff(ROBOTS(r).position_e(3), ROBOTS(r).position_t(3)); %bias
                %phi = mod(phi,2*pi);
                
%                 if phi > pi
%                     phi = phi - 2*pi;
%                 elseif phi < -pi
%                     phi = phi + 2*pi;
%                 end
                
                dists = [dists, d];
                angles = [angles, phi];
                if d < obj.detection_range
                    neigh = [neigh, ROBOTS(L).ID];
                end
            end
            
            obj.laser = dists;
            obj.bearing = angles;
            obj.neighbors = neigh;
            
        end
        
        function obj = encoder_measurement(obj)
            % get true velocity
            [V_t,yaw_rate_t] = obj.Ag2V();
            
            %  measure velocity
            obj.vel_m = V_t; %truth
            obj.vel_m = obj.vel_m+ normrnd(0,obj.sigmaVelocity,1,1); %noise 
            obj.vel_m = obj.vel_m+ obj.biasVelocity; % bias
           
            % measure yaw
            obj.yaw_rate_m = yaw_rate_t; %truth
            obj.yaw_rate_m = obj.yaw_rate_m + normrnd(0,obj.sigmaYawRate,1,1); % noise
            obj.yaw_rate_m = obj.yaw_rate_m + obj.biasYawRate; % bias
            
        end
        
        function [X,P] = get_states(obj,ROBOTS)
            numBots = length(ROBOTS);
            X = obj.X;
            P = obj.P;
            for i = 1:numBots
                X{i} = ROBOTS(i).position_e';
                for j = 1:numBots
                    if i == j
                        P{i,i} = ROBOTS(i).covariance_e;
                    else
                        P{i,j} = ROBOTS(i).P{i,j};
                    end
                    
                end
            end
        end
        
        function [states, covars] = get_locations(obj,ROBOTS)
            
            numbots = length(ROBOTS);
            states = obj.X{obj.ID};
            covars = obj.P{obj.ID,obj.ID};
            for L = 1:numbots % other robot
                d1_2 = ROBOTS(L).laser(obj.ID);
                d2_1 = obj.laser(L);
                phi2_1 = obj.bearing(L);
                phi1_2 = ROBOTS(L).bearing(obj.ID);
                
                if L ~= obj.ID && d1_2 < obj.detection_range
                    
                    x1_2 = obj.X{L}(1) + d1_2 * cos(phi1_2);
                    y1_2 = obj.X{L}(2) + d1_2 * sin(phi1_2);
                    yaw1_2 = obj.X{obj.ID}(3) + angdiff(phi2_1,phi1_2+pi);
                    
                    if abs(yaw1_2-obj.X{obj.ID}(3)) > .000001
                       disp("yaw estimation error"); 
                    end
                    
%                     if yaw1_2 > pi
%                         yaw1_2 = yaw1_2 - 2*pi;
%                     elseif yaw1_2 < -pi
%                         yaw1_2 = yaw1_2 + 2*pi;
%                     end
                    
                   % yaw1_2 = mod(yaw1_2,2*pi);
                    R = diag([obj.sigmaRange, obj.sigmaRange,obj.sigmaHeading]);
                    
                    states(:,end+1) = [x1_2;y1_2;yaw1_2];
                    covars(:,:,end+1) = obj.P{L,L} + R;
                    
                end
%%                 d = obj.laser(L);
%                 phi = obj.bearing(L)+pi;
%                 
%                 %if the other robot is in detection / communication range
%                 %give it our dead-reckoning prediction of where it is
%                 %update our particle if we have one there already
%                 
%                 if L ~= obj.ID
%                     dx = d*cos(phi); %from r -> L
%                     dy = d*sin(phi); %from r -> L
%                     x0 = obj.X{L}(1);%ROBOTS(L).position_e(1); %r pose
%                     y0 = obj.X{L}(2);%ROBOTS(L).position_e(2); %r pose
%                     theta = obj.X{obj.ID}(3);%ROBOTS(L).position_e(3);
%                     %give L, r's position of L, and mark that it has that
%                     %particle
%                     states(:,end+1) = [x0+dx;y0+dy];
%                     covars(:,:,end+1) = ROBOTS(L).covariance_d(1:2,1:2);%obj.P{L,L}(1:2,1:2);
%                     
%                 end
                
            end
            %covars = covars(:,:,2:end);
            
        end
        
        %% KINEMATIC UPDATE -----------------------------------------------
        
        function obj = update(obj)
            
            %determine if we are a beacon-------------------------------------------
            if obj.is_beacon == 1 && rand > obj.time_as_beacon/100 % remain a beacon
                obj.velocity_e = [0,0];
                obj.velocity_t = [0,0];
                obj.velocity_d = [0,0];
            elseif obj.is_beacon == 1 % stop becoming a beacon
                obj.is_beacon = 0;
            else                     % i am not a beacon
                
                %perform dead_reckoning
                obj = obj.dead_reckoning();
                
                % update estimate of location
                obj = obj.estimate_location();
                
                
                % update truth velocity and position
                % obj.velocity_t = obj.velocity_t + obj.acceleration*obj.dt;
                
                [V,yaw_rate] = obj.Ag2V();
                new_theta = obj.position_t(3) + yaw_rate*obj.dt;
                obj.velocity_t = V*[cos(new_theta), sin(new_theta)];
                
                % ttheta = atan2(obj.velocity_t(2),obj.velocity_t(1));
                ttheta = new_theta;
                obj.position_t = [obj.position_t(1:2) + obj.velocity_t*obj.dt, ttheta];
                
                % check if we can see home
                obj = obj.home_update(obj.detection_range);
                
                %record paths
                obj.path_t = [obj.path_t; obj.position_t];
                obj.path_d = [obj.path_d; obj.position_d];
                obj.path_e = [obj.path_e; obj.position_e];%(1:2)
                
                %set acceleration to zero
                obj.acceleration = [0 0];
                
                % check if we reached a goal or not
                if norm(obj.position_e(1:2) - obj.goal) < obj.detection_range
                    obj.found_goal = 1;
                end
                
            end
        end
        
        function [V,yaw_rate] = Ag2V(obj)
            %covert Accelleration to velocity and yaw_rate
            ax = obj.acceleration(1);
            ay = obj.acceleration(2);
            theta = obj.position_t(3);
            V = norm(obj.velocity_t) + (ax*cos(-theta) -ay*sin(-theta))*obj.dt;
            if abs(V) > obj.max_speed
               V = obj.max_speed;
            end
             
%             A_per = (ay*cos(theta) +ax*sin(theta));
%             yaw_rate = A_per/V;
%             if abs(yaw_rate) > .4
%                 yaw_rate = .4;
%             end
              if norm(obj.acceleration) ~= 0
                  desired = obj.max_speed*obj.acceleration/norm(obj.acceleration);
                  desired_yaw = atan2(desired(2),desired(1));
                  yaw_error = -angdiff(desired_yaw,obj.position_t(3));
                  yaw_rate = yaw_error;
              else
                  yaw_rate = 0;
              end
              
            
            
        end
        
        %% LOCALIZATION FUNCTIONS -----------------------------------------
        
        function obj = estimate_location(obj)
            switch (obj.estimator)
                case 0 % just use dead_reckoning
                    obj.position_e = obj.position_d;
                    obj.velocity_e = obj.velocity_d;
                    obj.covariance_e = obj.covariance_d;
                case 1 % covariance intersection
                    obj = obj.covariance_intersection();
                case 2 % decentralized ekf
                    obj = obj.decentralized_ekf();
                case 3 % centralized ekf
            end
        end
        
        function obj = dead_reckoning(obj)
            % update dead reckoning
            new_theta = obj.position_d(3) + obj.yaw_rate_m*obj.dt;
            obj.velocity_d = obj.vel_m*[cos(new_theta), sin(new_theta)];
            obj.position_d = [obj.position_d(1:2) + obj.velocity_d*obj.dt, new_theta];
            
            F_d = [1,0,-obj.vel_m*sin(new_theta)*obj.dt;  % X
                0,1, obj.vel_m*cos(new_theta)*obj.dt;  % Y
                0,0,           1             ]; % Yaw
            
            
            Q_d = diag([obj.sigmaVelocity, obj.sigmaVelocity, obj.sigmaYawRate]);
            
            old_covar = obj.covariance_d;
            obj.covariance_d = F_d*obj.covariance_d*(F_d') + Q_d;
            if min(eig(obj.covariance_d)) < 0
                pause(.1);
            end
            
        end
        
        % COVARIANCE INTERSECTION -----------------------------------------
        
        function obj = covariance_intersection(obj)
            % measure error in variance and dead reckoning mean error
            states = obj.state_particles{1};
            covars = obj.state_particles{2};
            
            %------------------------------ CI -----------------------
            if length(obj.neighbors) > 1
                disp('did covariance intersection with robot')
                disp(obj.ID)
                
                %---------------------------FAST CI
                %[mean_pose,covar] = fusecovint(states,covars);
                [mean_pose,covar] = fast_CI(states,covars);
                temp = zeros(3,3);
                temp(1,1) = covar(1,1);
                temp(2,2) = covar(2,2);
                temp(3,3) = covar(3,3);
                covar = temp;
                
                
                
                %---------------------------------------------
                if norm(mean_pose' - obj.path_e(end,:)) > 4
                   disp("very bad"); 
                end
                
                pause(.00001);
                obj.position_e = mean_pose';
                obj.covariance_e = covar;
%                 R = diag([obj.sigmaRange, obj.sigmaRange,obj.sigmaHeading]);
%                 covar = covar+R;

                
                %---------------------use CI with Kalman update --------------
            
%                 X_p = obj.position_e';
%                 P_p = obj.covariance_e;
%                 Y_p = obj.position_e(1:2)';
% 
%                 Y_m = mean_pose;
%                 P_m = covar;
% 
%                 H = [1,0,0;
%                      0,1,0];
% 
%                 I = eye(3);
% 
%                 residual = Y_m - Y_p;
%                 S = H*P_p*H' + P_m;
%                 K = P_p*H'*inv(S);
%                 obj.position_e = (X_p + K*residual)';
%                 obj.covariance_e = (I-K*H)*P_p;
                
            end
            

            %-------------------------dead reckoning update---------------
            new_theta = obj.position_e(3) + obj.yaw_rate_m*obj.dt;
            obj.velocity_e = obj.vel_m*[cos(new_theta), sin(new_theta)];
            %new_theta = mod(new_theta,2*pi);
            obj.position_e = [obj.position_e(1:2) + obj.velocity_e*obj.dt, new_theta];
            
            F_d = [1,0,-obj.vel_m*sin(new_theta)*obj.dt;  % X
                0,1, obj.vel_m*cos(new_theta)*obj.dt;     % Y
                0,0,           1             ];           % Yaw
            
            Q_d = diag([obj.sigmaVelocity, obj.sigmaVelocity, obj.sigmaYawRate]);
            
            old_covar = obj.covariance_e;
            
            obj.covariance_e = F_d*obj.covariance_e*F_d' + Q_d;
            
            %------------------------------------------------------
            
            if min(eig(obj.covariance_e)) < 0
                pause(.1);
            end
            
        end
        
        % DECENTRALIZED EKF -----------------------------------------------
        
        function[]= Decentralized_EKF()
            % Kinematic Measurement NOISE
                % Motion Update
                % True Motion
            % Lidar Measurement NOISE
                % Base Update
                % Neighbors Update
            
        end

        function [Xt] = True_Motion(X,U,dt)
        % This funcion gives you the true location of a robot
        %%% INPUT %%%
        % X is the current state matrix for robot i
        % i refers to the number of the robot i
        % U is input for robot i
        v = U(1); % v is the velocity input with no noise
        w = U(2); % w is the omega input with no noise
        %%% OUTPUT %%%
        % Xt is the a true state matrix for robot i

        % True location
        Xt = zeros(3,1); % Initialize
        Xt(1,1) = X(1) + v * dt * cos(X(3) + w * dt); % True x
        Xt(2,1) = X(2) + v * dt * sin(X(3) + w * dt); % True y
        Xt(3,1) = X(3) + w * dt; % True theta
        end

        function [Xp,Pp] = Motion_Update(X,P,U,i,dt)
        % This funcion runs an independent motion update for robot i
        number_of_robots = size(P,2); % Set the number of robots
        P_i = P{1,i}; % Set the covariance matrix for robot i
        %%% ASSUMPTIONS %%%
        % Q is the estimation noise covariance
        % White Gaussian noise N(0,q) with 0 mean and q stdv
        q = 0.1; % Stdv
        Q = (q^2) * eye(3); % Estimation noise covariance
        %%% INPUT %%%
        % X is the current state matrix for robot i
        % P_i is the current covariance matrix for robot i
        % C_i is the current correlated matrixes for robot i to the rest
        % P is the combination of P_i and C_i
        % i refers to the number of the robot i
        % U is input for robot i
        v = U(1); % v is the velocity input with noise in the measurement
        w = U(2); % w is the omega input with noise in the measurement
        %%% OUTPUT %%%
        % Xp is the a priori estimation for the state matrix for robot i
        % P_p is the a priori estimation for the covariance matrix for robot i
        % C_p is the a priori estimation for the correlated matrixes for robot i to the rest
        % Pp is the combination of P_i_p and C_p

        % A priori estimation for the state matrix
        f = zeros(3,1); % Initialize
        f(1,1) = X(1) + v * dt * cos(X(3) + w * dt); % Estimation of x
        f(2,1) = X(2) + v * dt * sin(X(3) + w * dt); % Estimation of y
        f(3,1) = X(3) + w * dt; % Estimation of theta
        Xp = f; % Estimated position

        % Linearize
        F = zeros(3); % Initialize
        F(1,:) = [1 , 0 , -v * dt * sin(X(3) + w * dt)]; % Jacobbian for x input
        F(2,:) = [0 , 1 , v * dt * cos(X(3) + w * dt)]; % Jacobbian for y input
        F(3,:) = [0 , 0 , 1]; % Jacobbian for theta input

        % A priori estimation for the covariance matrix
        Pp = cell(1,number_of_robots); % Initialize
        P_p = F * P_i * F' + Q; % Covariance for robot i
        Pp{1,i} = P_p; % Append estimation of covariance matrix
        % A priori estimation for the correlated matrixes 
        for j = 1 : number_of_robots % For each robot in the total number of robots
            if j == i % If robot j is equal to robot i 
                % Do nothing
            else % If robot j is not equal to robot i
            C_i = P{1,j}; % Set the correlated values for that robot
            C_p = F * C_i; % Correlated values for each robot from robot i
            Pp{1,j} = C_p; % Append estimation of correlated values matrix
            end
        end
        end        
         
        function [b,Zt] = Base_Range(X,B,range)
        % This funcion checks if the base is in range and calculates its true range
        %%% INPUT %%%
        % X is the current state matrix for robot i
        % B is the base location
        % range is the range distance for robot i to detect neighbors
        %%% OUTPUT %%%
        % b is the robot IDs that will be the neighbors for robot i
        % Zt is the a true ranging measurement for robot i to the base

        Zt(1,1) = sqrt(((X(1)-B(1))^2)+((X(2)-B(2))^2)); % True Rho measurement
        Zt(2,1) = atan2(X(2)-B(2),X(1)-B(1)); % True Phi measurement

        if Zt(1,1) > range % If robot out of range of base
            b = 0; % Mark base as out of range
            Zt(1,1) = 0; % Set the Rho measurement = 0
            Zt(2,1) = 0; % Set the Phi measurement = 0
        else % If robot in range with base
            b = 1; % Mark base as in range
        end
        end
        
        function [Xp,Pp] = Private_Measurement_Update(X,P,B,Z,i)
        % This funcion runs a private measurement update for robot i
        number_of_robots = size(P,2); % Set the number of robots
        P_i = P{1,i}; % Set the covariance matrix for robot i
        I = eye(3); % Identity Matrix
        %%% ASSUMPTIONS %%%
        % If robot i detects base, it gets perfect position update
        % R is the measurement noise covariance
        % White Gaussian noise N(0,r) with 0 mean and r stdv
        r = 0.000001; % Stdv
        R = (r^2) * eye(2); % Estimation noise covariance
        %%% INPUT %%%
        % X is the current state matrix for robot i
        % P_i is the current covariance matrix for robot i
        % C_i is the current correlated matrixes for robot i to the rest
        % P is the combination of P_i and C_i
        % B is the base location
        % i refers to the number of the robot i
        % Z is the private measurement from robot i to base
        rho = Z(1); % rho is the distance from robot i to base
        phi = Z(2); % phi is the angle from robot i to base
        %%% OUTPUT %%%
        % Xp is the a priori estimation for the state matrix for robot i
        % P_p is the a priori estimation for the covariance matrix for robot i
        % C_p is the a priori estimation for the correlated matrixes for robot i to the rest
        % Pp is the combination of P_i_p and C_p

        % Measurement to base
        h = zeros(2,1); % Initialize
        h(1,1) = sqrt(((X(1)-B(1))^2)+((X(2)-B(2))^2)); % Expected rho measurement
        h(2,1) = atan2(X(2)-B(2),X(1)-B(1)); % Expected phi measurement

        % Linearize 
        H(1,:) = [ (X(1)-B(1))/(sqrt(((X(1)-B(1))^2)+((X(2)-B(2))^2))) , (X(2)-B(2))/(sqrt(((X(1)-B(1))^2)+((X(2)-B(2))^2))) , 0]; % Jacobbian for rho input
        H(2,:) = [ -(X(2)-B(2))/(((X(1)-B(1))^2)+((X(2)-B(2))^2)) , (X(1)-B(1))/(((X(1)-B(1))^2)+((X(2)-B(2))^2)) , 0]; % Jacobbian for phi input

        S = H * P_i * H' + R; % Innovation Covariance Formula
        K = P_i * H' * inv(S); % Kalman Gain Formula

        RESIDUAL = Z - h; % Residual Formula

        Xp = X + K * RESIDUAL; % A posteriori estimation for the state matrix

        Pp = cell(1,number_of_robots); % Initialize
        P_p = (I - K * H) * P_i; % A posteriori estimation for the covariance matrix
        Pp{1,i} = P_p; % Append the covariance matrix
        % A posteriori estimation for the correlated matrixes 
        for j = 1:number_of_robots % For each robot
            if j == i
                % Do nothing
            else
                C_i = P{1,j}; % Set the correlated values for that robot
                C_p = (I - K * H) * C_i; % Correlated values for each robot from robot i
                Pp{1,j} = C_p; % Append estimation of correlated values matrix
            end
        end
        end
        
        function [N,Yt] = Neighbors_Range(X,i,range)
        % This funcion picks all neighbors for robot i
        number_of_robots = size(X,2); % Set the number of robots
        %%% INPUT %%%
        % X is the current state matrix for all the robots
        % i is the ID for robot i
        % range is the range distance for robot i to detect neighbors
        %%% OUTPUT %%%
        % N is the robot IDs that will be the neighbors for robot i
        % Yt is the a true ranging measurement for robot i to every neighbor

        Xi = X{i}; % State Matrix for robot i
        for j = 1:number_of_robots % For each robot
            Xj = X{j}; % State Matrix for robot j
            if i == j % If robot i = robot j
                D(j,1) = 0; % Possible neighbor ID = 0
                D(j,2) = 0; % Possible neighbor ID = 0
            else
                D(j,1) = sqrt(((Xj(1)-Xi(1))^2)+((Xj(2)-Xi(2))^2)); % True Rho measurement
                D(j,2) = atan2(Xj(2)-Xi(2),Xj(1)-Xi(1)); % True Phi measurement
            end
            if D(j,1) > range % If robot j out of range of robot i
                D(j,1) = 0; %Possible neighbor ID = 0
                D(j,2) = 0; %Possible neighbor ID = 0
            else
                % Do nothing
            end
        end

        N = []; % Initialize
        Yt = []; % Initialize
        PN = find(D); % Find possible neighbor ID for each robot
        if isempty(PN) == 1 % No neighbor around
            N = [0]; % Set N = 0
            Yt = [0,0]; % Set range = 0
        else
            for k = 1:length(PN) % For each robot
                if PN(k) <= number_of_robots
                    N = [N, PN(k)]; % Append neighbor
                    Yt = [Yt;D(PN(k),:)];% Append measurement
                else
                    % Do nothing
                end
            end
        end
        end       
        
        function [Xip,Xjp,Pip,Pjp] = Relative_Measurement_Update(Xi,Xj,Pi,Pj,Y,i,j)

        % This funcion runs a relative measurement update for robot i
        number_of_robots = size(Pi,2); % Set the number of robots
        number_of_robots = size(Pj,2); % Set the number of robots

        Xx = [Xi ; Xj]; % Combined State matrix
        Pi_i = Pi{1,i}; % Set the covariance matrix for robot i
        Pj_i = Pj{1,j}; % Set the covariance matrix for robot j
        Ci_i = Pi{1,j}; % Correlated value from robot i to robot j
        Cj_i = Pj{1,i}; % Correlated value from robot j to robot i
        Pij = Ci_i * Cj_i'; % Correlated values between robot i and robot j
        Px = [Pi_i Pij ; Pij' Pj_i]; % Combined covariance matrix
        I = eye(6); % Identity Matrix
        %%% ASSUMPTIONS %%%
        % If robot i detects robot j, robot j detects robot i -> (360º detection)
        % R is the measurement noise covariance
        % White Gaussian noise N(0,r) with 0 mean and r stdv
        rs = 0.01; % Stdv
        R = (rs^2) * eye(2); % Estimation noise covariance
        %%% INPUT %%%
        % Xi is the current state matrix for robot i
        % Pi_i is the current covariance matrix for robot i
        % Ci_i is the current correlated matrixes for robot i to the rest
        % Pi is the combination of Pi_i and Ci_i
        % Xj is the current state matrix for robot j
        % Pj_i is the current covariance matrix for robot j
        % Cj_i is the current correlated matrixes for robot j to the rest
        % Pj is the combination of Pj_i and Cj_i
        % i refers to the number of the robot i
        % j refers to the number of the robot j
        % Y is the relative measurement from robot i to j / robot j to i
        % Yr is the measurement with noise
        rho = Y(1); % rho is the distance from robot i to rotob j with noise in the measurement
        phi = Y(2); % phi is the angle from robot i to robot j with noise in the measurement
        Yr = [rho ; phi]; % Measurement input
        %%% OUTPUT %%%
        % Xip is the a priori estimation for the state matrix for robot i
        % Pi_p is the a priori estimation for the covariance matrix for robot i
        % Ci_p is the a priori estimation for the correlated matrixes for robot i to the rest
        % Pip is the combination of Pi_p and Ci_p
        % Xjp is the a priori estimation for the state matrix for robot j
        % Pj_p is the a priori estimation for the covariance matrix for robot j
        % Cj_p is the a priori estimation for the correlated matrixes for robot j to the rest
        % Pjp is the combination of Pj_p and Cj_p

        % Expected Measurement
        h = zeros(2,1); % Initialize
        h(1,1) = sqrt(((Xj(1)-Xi(1))^2)+((Xj(2)-Xi(2))^2)); % Expected rho measurement
        h(2,1) = atan2(Xj(2)-Xi(2),Xj(1)-Xi(1)); % Expected phi measurement

        % Linearize
        H(1,:) = [ -(Xj(1)-Xi(1))/(sqrt(((Xj(1)-Xi(1))^2)+((Xj(2)-Xi(2))^2))) , -(Xj(2)-Xi(2))/(sqrt(((Xj(1)-Xi(1))^2)+((Xj(2)-Xi(2))^2))) , 0 , (Xj(1)-Xi(1))/(sqrt(((Xj(1)-Xi(1))^2)+((Xj(2)-Xi(2))^2))) , (Xj(2)-Xi(2))/(sqrt(((Xj(1)-Xi(1))^2)+((Xj(2)-Xi(2))^2))) , 0]; % Jacobbian for rho input
        H(2,:) = [ (Xj(2)-Xi(2))/(((Xj(1)-Xi(1))^2)+((Xj(2)-Xi(2))^2)) , -(Xj(1)-Xi(1))/(((Xj(1)-Xi(1))^2)+((Xj(2)-Xi(2))^2)) , 0 , -(Xj(2)-Xi(2))/(((Xj(1)-Xi(1))^2)+((Xj(2)-Xi(2))^2)) , (Xj(1)-Xi(1))/(((Xj(1)-Xi(1))^2)+((Xj(2)-Xi(2))^2)) , 0]; % Jacobbian for phi input


        S = H * Px * H' + R; % Innovation Covariance Formula
        K = Px * H' * inv(S); % Kalman Gain Formula

        RESIDUAL = Yr - h; % Residual Formula 

        Xp = Xx + K * RESIDUAL; % A posteriori estimation for the combined state matrix
        Xip = Xp(1:3); % A posteriori estimation for the state matrix of robot i
        Xjp = Xp(4:6); % A posteriori estimation for the state matrix of robot j

        Pp = (I - K * H) * Px; % A posteriori estimation for the combined covariance matrix

        Pip = cell(1,number_of_robots); % Initialize
        Pip{1,i} = Pp(1:3,1:3); % Covariance a for robot i
        Pip{1,j} = Pp(1:3,4:6); % Correlated value from robot i to robot j
        for k = 1:number_of_robots % For each robot
            if k == i
                % Do nothing
            elseif k == j
                % Do nothing
            else
                Pip{1,k} = Pip{1,i} * inv(Pi{1,i}) * Pi{1,k}; % Correlated values from robot i to the rest of the robots
            end
        end

        Pjp = cell(1,number_of_robots); % Initialize
        Pjp{1,i} = eye(3); % Correlated values for robot j to robot i
        Pjp{1,j} = Pp(4:6,4:6); % Covariance for robot j
        for k= 1:number_of_robots
            if k==i
                % Do nothing
            elseif i ==j
                % Do nothing
            else
                Pjp{1,k} = Pjp{1,j} * inv(Pj{1,j}) * Pj{1,k};  % Correlated values from robot j to the rest of the robots
            end
        end
        end
        
        % OTHER -----------------------------------------------------------
        
        function obj = home_update(obj,home_range)
            
            home_dist = norm(obj.position_t(1:2) - obj.home);
            if home_dist < home_range
                % update location
                obj.covariance_d = [.1,  0,  0;
                    0, .1   0;
                    0,  0, .1];
                obj.covariance_e = obj.covariance_d;
                obj.position_d = obj.position_t; % + normrnd(0,.001,1,3);
                obj.position_e = obj.position_d;
               % obj.position_e(3) = mod(obj.position_e(3),2*pi);
                
                %get color particles
                if home_dist < home_range %within 5 squares
                    theta = atan2d(obj.position_t(2) - obj.home(2),obj.position_t(1) - obj.home(1));
                    if theta < -120 %red range
                        obj.color_particles(1) = obj.color_particles(1) + 5;
                    elseif theta < 0 %green
                        obj.color_particles(2) = obj.color_particles(2) + 5;
                    elseif theta < 120 %blue
                        obj.color_particles(3) = obj.color_particles(3) + 5;
                    else % red range
                        obj.color_particles(1) = obj.color_particles(1) + 5;
                    end
                    
                end
            end
            
            
        end
        
        %% BEACON FUNCTIONS -----------------------------------------------
        
        % NEEDS TO BE FIXED!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
        function ROBOTS = beacon_update(ROBOTS,ID,neighbors,cov_max)
            
            found_beacon = 0;
            beacon = [];
            % if norm(ROBOTS(ID).mean_covar) < cov_max
            %     ROBOTS(ID).is_beacon =0;
            % end
            
            if ROBOTS(ID).is_beacon == 1 && length(neighbors) <= 1
                ROBOTS(ID).time_as_beacon = ROBOTS(ID).time_as_beacon+1;
                found_beacon = 1;
                beacon = ID;
            end
            
            for r = neighbors
                if r.is_beacon == 1
                    found_beacon =1;
                    if length(neighbors) <= 1
                        ROBOTS(r.ID).time_as_beacon = ROBOTS(r.ID).time_as_beacon+1;
                    else
                        ROBOTS(r.ID).time_as_beacon = 0;
                    end
                    beacon = r.ID;
                    break;
                end
            end
            
            if found_beacon == 1
                for r = neighbors
                    if norm(r.mean_covar) > norm(ROBOTS(beacon).mean_covar) %may need to flip the sign
                        ROBOTS(beacon).is_beacon = 0;
                        ROBOTS(beacon).time_as_beacon = 0;
                        ROBOTS(r.ID).is_beacon = 1;
                        ROBOTS(r.ID).time_as_beacon = 0;
                        beacon = r.ID;
                    end
                end
            else
                if norm(ROBOTS(ID).mean_covar) > cov_max
                    ROBOTS(ID).is_beacon =1;
                    ROBOTS(ID).time_as_beacon = 0;
                end
                
            end
            
            
        end
        
        %% COLOR PARTICLE FUNCTIONS ---------------------------------------
        
        function [obj, other] = trade_color(obj,other)
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
        
        %% DISPLAY FUNCTIONS ----------------------------------------------
        
        function disp_swarm(ROBOTS,range,show_detection_rng)
            
            numBots = length(ROBOTS);
            KA = [];
            KC = [];
            KS = [];
            KH = [];
            KG = [];
            clf();
            %subplot(2,3,1);
            for r = 1:numBots
                % plot truth data-----------------------------------------
                
                plot(ROBOTS(r).path_t(end,1), ROBOTS(r).path_t(end,2), 'ks');
                hold on;
                if show_detection_rng
                    viscircles([ROBOTS(r).path_t(end,1),ROBOTS(r).path_t(end,2)],range);
                    hold on;
                end
                %plot estimated position and color-------------------------------------------
                error_ellipse(ROBOTS(r).covariance_e(1:2,1:2), [ROBOTS(r).position_e(1), ROBOTS(r).position_e(2)],'conf',.5)
                hold on;
                if sum(ROBOTS(r).color_particles) > 0
                    COLOR= ROBOTS(r).color_particles./sum(ROBOTS(r).color_particles);
                else
                    COLOR = [0,0,0];
                end
                
                if ROBOTS(r).is_beacon == 1
                    plot(ROBOTS(r).position_e(1), ROBOTS(r).position_e(2), '^', 'color', COLOR);
                    hold on;
                else
                    plot(ROBOTS(r).position_e(1), ROBOTS(r).position_e(2), '*', 'color', COLOR);
                    hold on;
                end
                % plot dead reckoning position---------------------------------------------------------
                plot(ROBOTS(r).position_d(1), ROBOTS(r).position_d(2), 'bo');
                hold on;
                quiver(ROBOTS(r).position_d(1), ROBOTS(r).position_d(2),ROBOTS(r).velocity_d(1), ROBOTS(r).velocity_d(2), 'b');
                hold on;
                
                %plot goal position---------------------------------------------
                plot(ROBOTS(r).goal(1), ROBOTS(r).goal(2), 'rx')
                
                KA = [KA,ROBOTS(r).Ka];
                KC = [KC,ROBOTS(r).Kc];
                KS = [KS,ROBOTS(r).Ks];
                KH = [KH,ROBOTS(r).Kh];
                KG = [KG,ROBOTS(r).Kg];
            end
            %plot home------------------------------------------------------
            plot(ROBOTS(1).home(1),ROBOTS(1).home(2), 'bd','markersize',12)
            hold on;
            viscircles([ROBOTS(1).home(1),ROBOTS(1).home(2)],range);
            hold on;
            title("Square = truth, * = estimate, o = dead reckoning");
            axis([-50 50 -50 50])
            
            %plot gain distributions
            %     subplot(2,3,2)
            %     histogram(KA)
            %     title("alignment gain")
            %     subplot(2,3,3)
            %     histogram(KC)
            %     title("cohesion gain")
            %     subplot(2,3,4)
            %     histogram(KS)
            %     title("Seperation gain")
            %     subplot(2,3,5)
            %     histogram(KH)
            %     title("Home gain")
            %     subplot(2,3,6)
            %     histogram(KG)
            %     title("Goal gain")
            
            
            pause(.0001);
        end
               
    end
end
