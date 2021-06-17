function robot = boids_update(robot,e_max,rho_max)
%UNTITLED9 Summary of this function goes here
%   Detailed explanation goes here

    % measure local density
    A = pi*robot.detection_range^2;
    rho = length(robot.neighbors) / A;
    
    % measure error in variance and dead reckoning mean error
    if sum(robot.particles(3,:)) > 2
        x_mean = mean(robot.particles(1,robot.particles(3,:) >.5));
        y_mean = mean(robot.particles(2,robot.particles(3,:) >.5));
        covar =  cov(robot.particles(1:2,robot.particles(3,:) >.5)');
   
        robot.mean_position = [x_mean,y_mean];
        robot.covariance = covar;
    end
    mean_error = norm(robot.position - robot.mean_position);
    
    % update boids parameters
    robot.Ka = rho/rho_max + mean_error/e_max;
    robot.Kc = (norm(robot.covariance) + mean_error^2)/A; %norm([norm(robot.covariance), mean_error^2]);
    robot.Ks = A/(norm(robot.covariance) + mean_error^2);
    robot.Kh = mean_error^2 / norm(robot.covariance);
    
end

