import numpy as np
import sim
import media_export as export

#model imports
from models import LenardJones as lj
from models import Boids as bo
from models import PFSM
from models import Dance

#all parameters for simulation
params = sim.SimParams(
    num_agents=200, 
    dt=0.1, 
    overall_time = 15, 
    enclosure_size = 10, 
    init_pos_max= 3, #if None, then defaults to enclosure_size
    agent_max_vel=5,
    agent_max_accel=np.inf,
    agent_max_turn_rate=1.5*np.pi,
    neighbor_radius=3,
    periodic_boundary=True
    )

#define list of controllers
controllers= [bo.Boids(3,5,0.1,1) for i in range(params.num_agents)]

agentPositions, agentVels = sim.runSim(controllers,params,progress_bar=True)
print("Sim finished -- Generating media")

#export types, NONE, INTERACTIVE, GIF, MP4
media_type = export.ExportType.GIF

export.export(media_type,"new",agentPositions,params=params,vision_mode=False,progress_bar=True)
print("Media generated")