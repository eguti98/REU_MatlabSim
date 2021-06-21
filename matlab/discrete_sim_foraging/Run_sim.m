%script to start simulation
clc;
clear all;
close all;

init_food_num = 10;
init_density_food = 5;
init_num_bots = 1;
init_home_loc = [10,10]; %home location in X-Y

%where to randomly spawn the robots in
robot_home_bounds = [0,10];

%set up a world object with a world bitmap image

%Set up simluation
world1 = World("world_image_1.png");
world1.gen_bots(5);
world1.gen_food(.1);

for i = 1:1
    disp("Starting Simulation!");
    for ii=0:100000 %simulation ticks
        world1.tick();
        pause(.1);
    end

end