# even this will become another function eventually
from pipeline_tools.learning import learnMotionConstraints, learnNeighborRadius, learnGainsLinearRegression, learnGainsNonLinearOptimization
from sim_tools import sim
from sim_tools import media_export as export
from imitation_tools import data_prep
from features.features import *
from models.featureCombo import FeatureCombo as fc
from models.featureComboEnv import FeatureComboEnv as fcE
from pipeline_tools import transformations

from tqdm import tqdm
import numpy as np
import copy
import os

# params = sim.SimParams(
#     num_agents=40,
#     dt=0.05,
#     overall_time=30,
#     enclosure_size=20,
#     init_pos_max=None,  # if None, then defaults to enclosure_size
#     agent_max_vel=7,
#     init_vel_max=None,
#     agent_max_accel=np.inf,
#     agent_max_turn_rate=np.inf,
#     neighbor_radius=5,
#     periodic_boundary=False
# )

if __name__ == '__main__':
    # INITIAL GENERATION
    # importing from a video now, so need to specify all params

    # need an npz with num_agents, overall_time, steps, agentPositions, enclosure size
    datazip = np.load(
        'teaching_swarm_data/100_guppies_trex/100fish_parsed.npz')

    num_agents = datazip['num_agents']
    overall_time = datazip['overall_time']
    steps = datazip['steps']

    agentPositions = datazip['agent_positions']

    # enclosure bounding might need to be adjusted for non square
    enclosure_edge = datazip['enclosure_size']

    print("Num agents", num_agents)
    print("Overall time", overall_time)
    print("Steps", steps)
    print("Enclosure Size", enclosure_edge)
    print("Agent Positions", agentPositions.shape)

    overall_time = overall_time  # just speed it up the dumb way, not smoothing

    steps = steps-1  # steps technically refers to transformations, so 1 less than list of steps
    learnedParams = sim.SimParams()
    learnedParams.overall_time = overall_time
    learnedParams.dt = overall_time/steps
    learnedParams.num_agents = num_agents
    learnedParams.enclosure_size = enclosure_edge

    learning_soc_features = {
        "coh": Cohesion(),
        "align": Alignment(),
        "sep": SeparationInv2(),
        "sepExp": SeparationExp(),

        # # "sep6": SeparationInv6(),
        # # "sep12": SeparationInv12(),
        # "steer": SteerToAvoid(1.0, 5.5),  # need to change, ordering issues
        "rot": Rotation()
    }

    learning_env_features = {
        "inertia": Inertia(),
        # "boundSteer": RectangularBoundSteer(learnedParams.enclosure_size,
        #                                learnedParams.enclosure_size,
        #                                learnedParams.neighbor_radius),
        # "repulseSteer": RectangularBoundSeparationShapely(learnedParams.enclosure_size,
        #                         learnedParams.enclosure_size,
        #                         learnedParams.neighbor_radius)
    }

    # LEARNING
    # now all these initial things are manual
    # eventually should split params class itself, but that's for later

    if not os.path.exists("Output/Full_Pipeline_Output_Raw"):
        os.makedirs("Output/Full_Pipeline_Output_Raw")

    print("Exporting raw data to visualization")
    # export.export(export.ExportType.GIF, "Output/Full_Pipeline_Output_Raw/Initial",
    #               agentPositions, np.zeros(agentPositions.shape), learnedParams, progress_bar=True)  # velocities not used in export

    posVelSlices = data_prep.toPosVelSlices(agentPositions, learnedParams)

    posVelSlices = transformations.lowPassFilterVels(posVelSlices, 0.05)

    # need to apply a low pass filter by agent step
    learnedMCs = learnMotionConstraints(posVelSlices, learnedParams)

    print("Learned MCs", learnedMCs)
    learnedParams.agent_max_vel = learnedMCs["max_vel"]
    # other two aren't learned properly yet

    # need to work on running this in a fasterish form
    np.random.shuffle(posVelSlices)
    radius = learnNeighborRadius(
        posVelSlices[:500], learnedParams, learning_soc_features,learning_env_features)
    print("Learned Radius", radius)
    # radius = 5.5
    learnedParams.neighbor_radius = radius

    featureSlices = data_prep.toFeatureSlices(
        posVelSlices, social_features=learning_soc_features, env_features=learning_env_features, params=learnedParams,verbose=False)

    linear_gains = learnGainsLinearRegression(
        featureSlices, learnedParams, learning_soc_features, learning_env_features,verbose=False)
    print("Linear gains", linear_gains)

    improved_gains = learnGainsNonLinearOptimization(
        featureSlices, learnedParams, guess=linear_gains, maxSample=5000,verbose=False)
    print("Improved Gains", improved_gains)

    # RUN OUTPUT SIMS
    # make numbers line up
    # learnedParams.num_agents = params.num_agents
    # learnedParams.overall_time = params.overall_time
    # learnedParams.enclosure_size = params.enclosure_size

    soc_gains = improved_gains[:len(learning_soc_features)]
    env_gains = improved_gains[len(learning_soc_features):]
    imitation_controller = fcE(soc_gains, list(
        learning_soc_features.values()), env_gains, list(learning_env_features.values()))

    imitated_controllers = [copy.deepcopy(
        imitation_controller) for i in range(learnedParams.num_agents)]

    for controller in imitated_controllers:
        controller.setColor("red")

    print("Running Imitation Sim")
    imitSimPos, imitSimVels = sim.runSim(imitated_controllers, learnedParams,
                                         initial_positions=agentPositions[0], initial_velocities=posVelSlices[0].vel,
                                         progress_bar=False)
    # hybrid --no good way to show different radiuses right now, so not showing yet
    # mix_factor = 0.5
    # num_orig = (0.5*params.num_agents)
    # hybrid_controllers = orig_controllers[0:]

    np.set_printoptions(precision=4)

    #let's look at trajectories too 

    export.exportTrajectories("Output/Full_Pipeline_Output_Raw/Initial_trajs",agentPositions,learnedParams,0,3,size=2000)
    export.exportTrajectories("Output/Full_Pipeline_Output_Raw/Imitated_trajs",imitSimPos,learnedParams,0,3,size=2000)


    # EXPORT TO FILES
    print("Exporting to files")
    export.export(export.ExportType.GIF, "Output/Full_Pipeline_Output_Raw/Imitated_rad"
                  + str(radius)+"Gains:"+str(improved_gains).replace(" ", ",") +
                  "Maxv"+str(learnedParams.agent_max_vel),
                  imitSimPos, imitSimVels, learnedParams, progress_bar=False, controllers=imitated_controllers)
