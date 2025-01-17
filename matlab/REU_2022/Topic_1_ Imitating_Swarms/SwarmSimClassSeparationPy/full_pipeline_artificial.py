# even this will become another function eventually
from pipeline_tools.learning import learnMotionConstraints, learnNeighborRadius, learnGainsLinearRegression, learnGainsNonLinearOptimization
from pipeline_tools.prevalidation import plotNeighborRadius, testTrueNeighborRadius, testTrueGainsLinear, testTrueGainsNonLinear
from sim_tools import sim
from sim_tools import media_export as export
from imitation_tools import data_prep
from features.features import *
from models.featureCombo import FeatureCombo as fc
from models.featureComboEnv import FeatureComboEnv as fcE

from tqdm import tqdm
import numpy as np
import copy
import os

params = sim.SimParams(
    num_agents=40,
    dt=0.05,
    overall_time=30,
    enclosure_size=20,
    init_pos_max=None,  # if None, then defaults to enclosure_size
    agent_max_vel=7,
    init_vel_max=None,
    agent_max_accel=np.inf,
    agent_max_turn_rate=np.inf,
    neighbor_radius=5,
    periodic_boundary=False
)

if __name__ == '__main__':

    # INITIAL GENERATION
    orig_soc_features = [
        Cohesion(),
        Alignment(),
        SeparationInv2(),
        SteerToAvoid(params.neighbor_radius/4,params.neighbor_radius),
        Rotation(),
    ]

    orig_env_features = [
        Inertia(),
    ]


    true_gains = np.array([3, 0, 1,1,1,0])
    orig_controller = fcE(true_gains[:len(orig_soc_features)],orig_soc_features,true_gains[len(orig_soc_features):], orig_env_features)
    orig_controllers = [copy.deepcopy(orig_controller)
                        for i in range(params.num_agents)]

    print("Run and export initial sim")
    initSimPos, initSimVels = sim.runSim(
        orig_controllers, params, progress_bar=True)

    if not os.path.exists("Output/Full_Pipeline_Output_Artificial"):
        os.makedirs("Output/Full_Pipeline_Output_Artificial")

    print("Run Training Sims")
    # eventually would like to eliminate/reduce this step, and learn from primarily one big sim
    trainingParams = copy.deepcopy(params)
    trainingParams.num_agents = 10
    trainingParams.enclosure_size = 10
    trainingParams.init_vel_max = 1
    trainingParams.overall_time = 4
    num_sims = 100
    
    posVelSlices = []
    # posVelSlices = data_prep.toPosVelSlices(initSimPos,params)
    for i in tqdm(range(num_sims)):
        trainPositions, trainVels = sim.runSim(
            orig_controllers, trainingParams, progress_bar=False)

        # apply noise to position data
        # noise_percent = 0.001
        # for pos in trainPositions:
        #     # 0.6 to account for stdev value, so most things are within bounds
        #     # maybe should do the noise based on current vel
        #     noise = 0.6*noise_percent*params.agent_max_vel*np.random.normal(0,1,size=(2))*params.dt
        #     pos+=noise

        posVelSlices.extend(data_prep.toPosVelSlices(
            trainPositions, trainingParams))

    social_features = {
        "coh": Cohesion(),
        "align": Alignment(),
        "sep": SeparationInv2(),
        "steer":SteerToAvoid(params.neighbor_radius/4,params.neighbor_radius),
        "rot":Rotation()
    }

    env_features = {
        "inertia": Inertia(),
    }

    # VALIDATION
# 
    # realFeatureSlices = data_prep.toFeatureSlices(
    #     posVelSlices, social_features,env_features, trainingParams)
    # print("Neighbor radius true loss", testTrueNeighborRadius(
    #     posVelSlices, trainingParams, social_features,env_features))
    # print("Gain true loss for linear", testTrueGainsLinear(
    #     true_gains, realFeatureSlices, trainingParams))
    # print("Gain true loss for nonlinear", testTrueGainsNonLinear(
    #     true_gains, realFeatureSlices, trainingParams))

    # plotNeighborRadius(posVelSlices, trainingParams, social_features,env_features)

    # LEARNING
    # being very explicit here, only transferring from original exactly what we will transfer
    # eventually should split params class itself, but that's for later
    learnedParams = sim.SimParams()
    learnedParams.dt = trainingParams.dt
    learnedParams.num_agents = trainingParams.num_agents
    learnedParams.enclosure_size = trainingParams.enclosure_size

    learnedMCs = learnMotionConstraints(posVelSlices, learnedParams)

    print("Learned MCs", learnedMCs)
    learnedParams.agent_max_vel = learnedMCs["max_vel"]
    # other two aren't learned properly yet

    radius = learnNeighborRadius(
        posVelSlices, learnedParams, social_features,env_features)
    print("Learned Radius", radius)
    learnedParams.neighbor_radius = radius

    featureSlices = data_prep.toFeatureSlices(
        posVelSlices, social_features,env_features, learnedParams)

    linear_gains = learnGainsLinearRegression(
        featureSlices, learnedParams, social_features,env_features)
    print("Linear gains", linear_gains)

    improved_gains = learnGainsNonLinearOptimization(
        featureSlices, learnedParams, guess=linear_gains, maxSample=5000)
    print("Improved Gains", improved_gains)

    # RUN OUTPUT SIMS
    # make numbers line up
    learnedParams.num_agents = params.num_agents
    learnedParams.overall_time = params.overall_time
    learnedParams.enclosure_size = params.enclosure_size

    soc_gains = improved_gains[:len(social_features)]
    env_gains = improved_gains[len(social_features):]
    imitation_controller = fcE(soc_gains, list(
        social_features.values()), env_gains, list(env_features.values()))
    imitated_controllers = [copy.deepcopy(
        imitation_controller) for i in range(learnedParams.num_agents)]
    for controller in imitated_controllers:
        controller.setColor("red")

    print("Running Imitation Sim")
    imitSimPos, imitSimVels = sim.runSim(imitated_controllers, learnedParams,
                                         initial_positions=initSimPos[0], initial_velocities=initSimVels[0], progress_bar=True)
    # hybrid --no good way to show different radiuses right now, so not showing yet
    # mix_factor = 0.5
    # num_orig = (0.5*params.num_agents)
    # hybrid_controllers = orig_controllers[0:]

    # EXPORT TO FILES
    print("Exporting to files")
    export.export(export.ExportType.GIF, "Output/Full_Pipeline_Output/Initial",
                  initSimPos, initSimVels, params, progress_bar=True)
    export.export(export.ExportType.GIF, "Output/Full_Pipeline_Output/Imitated", imitSimPos,
                  imitSimVels, learnedParams, progress_bar=True, controllers=imitated_controllers)
