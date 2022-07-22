import numpy as np
import sim_tools.sim as sim
import sim_tools.media_export as export
import copy

# model imports
from models import LennardJones as lj
from models import Boids as bo
from models import PFSM
from models import Dance
from models import SteerControl as sc
from models import linearSuperSet as lss
from models.featureCombo import FeatureCombo as fc

import os
import plotly.express as px
import pandas as pd

# feature imports
from features.features import *

# all parameters for simulation
params = sim.SimParams(
    num_agents=40,
    dt=0.01,
    overall_time=20,
    enclosure_size=15,
    init_pos_max=None,  # if None, then defaults to enclosure_size
    agent_max_vel=7,
    init_vel_max=None,
    agent_max_accel=np.inf,
    agent_max_turn_rate=np.inf,
    neighbor_radius=3,
    periodic_boundary=False
)

if __name__ == '__main__':
    # define list of controllers
    features = [
        Cohesion(),  # on their own, seems tigther and less spread
        Alignment(),  # good
        SeparationInv2(),
        SteerToAvoid(params.neighbor_radius/4, params.neighbor_radius),
        Rotation()
    ]
    orig = fc([5, 5, 5, 5, 5], features)
    # orig = lss.SuperSet(1,1,0,3,0)
    controllers = [copy.deepcopy(orig) for i in range(params.num_agents)]

    # if you want to do coloring by agent
    for controller in controllers:
        # vals = np.random.uniform(0,1,3)*255
        # controller.setColor("rgb("+str(int(vals[0]))+","+str(int(vals[1]))+","+str(int(vals[2]))+")")
        controller.setColor("blue")

    agentPositions, agentVels = sim.runSim(
        controllers, params, progress_bar=True)
    print("Sim finished -- Generating media")

    if not os.path.exists("Output/TrajectoryExport"):
        os.makedirs("Output/TrajectoryExport")
    export.exportTrajectories("Output/TrajectoryExport/trajs",agentPositions,params,5,0.5)
    # time = 1
    # startTime = 3
    # start = int(startTime/params.dt)
    # num_frames = int(time/params.dt)
    # agentPositionsFirst20 = agentPositions[start:start+num_frames]

    # steps = len(agentPositionsFirst20)-1
    # df = pd.DataFrame(
    #     {
    #        "x":np.reshape(agentPositionsFirst20[:,:,0],params.num_agents*(steps+1)),
    #        "y":np.reshape(agentPositionsFirst20[:,:,1],params.num_agents*(steps+1)),
    #        "agent": np.tile(range(0,params.num_agents),steps+1)
    #     }
    # )

    # px.line(df,x="x",y="y",color="agent",title="Agent Trajectories").show()
    # export types, NONE, INTERACTIVE, GIF, MP4
    # media_type = export.ExportType.GIF

    # export.export(media_type,"new",agentPositions,agentVels,controllers=controllers,params=params,vision_mode=False,progress_bar=True)
    # print("Media generated")
