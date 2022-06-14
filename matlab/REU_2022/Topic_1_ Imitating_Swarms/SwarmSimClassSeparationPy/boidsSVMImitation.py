import numpy as np
import sim
import media_export as export
import time
import copy


from sklearn.linear_model import LinearRegression as lr
from tqdm import tqdm
from sklearn.metrics import mean_absolute_error
from sklearn.svm import SVR
from sklearn.model_selection import train_test_split
from dataclasses import dataclass #data class is like the python equivalent of a struct
from models import Boids as bo
from models import SVRBoids
import xgboost as xgb

import sys
sys.setrecursionlimit(2147483647)

params = sim.SimParams(
    num_agents=40,
    dt=0.05,
    overall_time = 15,
    enclosure_size = 10,
    init_pos_max= None, #if None, then defaults to enclosure_size
    agent_max_vel=5,
    init_vel_max = 2,
    agent_max_accel=2.1,
    agent_max_turn_rate=2*np.pi,
    neighbor_radius=3,
    periodic_boundary=False
    )

#constants to imitate
k_coh = 3
k_align = 5
k_sep = 0.1
k_inertia = 1

true_gains = [k_coh, k_align, k_sep, k_inertia]

#run sim
# print("Original agent slices")
controllers = [bo.Boids(*true_gains) for i in range(params.num_agents)]
agentPositions, agentVels = sim.runSim(controllers,params)

export.export(export.ExportType.GIF,"SVRInitial",agentPositions,agentVels,params=params,vision_mode=False)

# print("Agent positions:")
# print(agentPositions)
# print("Agent velocities:")
# print(agentVels)

#reformat positions and vels by slice
@dataclass
class posVelSlice:
    pos: np.ndarray
    vel: np.ndarray
    next_vel: np.ndarray

posVelSlices = [posVelSlice(agentPositions[i],agentVels[i],agentVels[i+1]) for i in range(len(agentPositions)-1)]

# print("PosVelSlices:")
# print(posVelSlices)

posVelSlices = []
#run tons more short sims
shortSimParams = copy.deepcopy(params)
print("Running short sims")
shortSimParams.overall_time = 2
# shortSimParams.enclosure_size = 2*params.enclosure_size
# shortSimParams.init_pos_max = params.enclosure_size/2

extra_sims = 3
for extra_sim in tqdm(range(extra_sims)):
    agentPositions, agentVels = sim.runSim(controllers,shortSimParams)
    posVelSlices.extend([posVelSlice(agentPositions[i],agentVels[i],agentVels[i+1]) for i in range(len(agentPositions)-1)])


#reformat slices to be relevant by agent, getting the centroid, separation, alignment, and last vel
@dataclass
class agentSlice:
    #inputs
    cohesion: np.ndarray
    alignment: np.ndarray
    separation: np.ndarray
    last_vel: np.ndarray
    #output
    output_vel: np.ndarray

agentSlices = []
for slice in posVelSlices:
    for agent in range(params.num_agents):
        #calculate all relevant derivate metrics, repackage
        posCentroid = np.zeros(2)
        velCentroid = np.zeros(2)
        agentPos = slice.pos[agent]
    
        #throw out data near the boundary, only needed with bounce
        if(agentPos[0] > params.enclosure_size or agentPos[0] < -params.enclosure_size 
        or agentPos[1] > params.enclosure_size or agentPos[1] < -params.enclosure_size):
            continue

        agentVel = slice.vel[agent]
        agentNextVel = slice.next_vel[agent]
        separation = np.zeros(2)

        adjacent = 0
        for otherAgent in range(params.num_agents):
            if otherAgent == agent:
                continue
            
            otherPos = slice.pos[otherAgent]

            if np.linalg.norm(otherPos-agentPos) > params.neighbor_radius:
                continue
            
            dist = np.linalg.norm(otherPos-agentPos)

            separation += ((otherPos-agentPos)/dist)*-1*(1/(dist**6))
            otherVel = slice.vel[otherAgent]
            posCentroid += otherPos
            velCentroid += otherVel
            adjacent += 1
        
        #throw out data without interactions
        if adjacent < 1:
            continue

        posCentroid /= adjacent
        velCentroid /= adjacent

        agentVelDifference = agentNextVel - agentVel

        agentSlices.append(agentSlice(posCentroid-agentPos,velCentroid,separation,np.zeros(2),agentVelDifference))

#sanity check, this should have 0 loss, anything else is either noise or bad measurements
true_loss = 0
for slice in agentSlices:
    gains_ex = true_gains[:3]
    args = np.array([slice.cohesion,slice.alignment,slice.separation])
    # print("Args",args)
    # print("Gains",gains_ex)
    vel_pred = np.dot(args.transpose(),gains_ex)
    # print("Pred",vel_pred)
    # need to add scaling
    if(np.linalg.norm(vel_pred) > params.agent_max_vel):
        vel_pred = vel_pred/np.linalg.norm(vel_pred)*params.agent_max_vel
    # print("Pred scaled",vel_pred)
    # print("output",slice.output_vel)

    err = vel_pred - slice.output_vel
    #print("err",err)
    true_loss += np.linalg.norm(err)
true_loss/=len(agentSlices)
print("True loss(data deviation from original on average):",true_loss)


print("Ignored ",(len(posVelSlices)*params.num_agents)-len(agentSlices),"/",len(posVelSlices)*params.num_agents," slices")

x = []
y = []

np.random.shuffle(agentSlices)
for slice in agentSlices:
    x.append(np.array([slice.cohesion[0],slice.alignment[0],slice.separation[0],slice.cohesion[1],slice.alignment[1],slice.separation[1]]))
    y.append(slice.output_vel)

x = np.array(x)
y = np.array(y).transpose()

# print(x)
# print(y.shape)


#clipping a lot of data here, might do smart subsampling
#train 2 SVRs for the purpose, one for x, one for y
x_train0, x_test0, y_train0, y_test0 = train_test_split(x[:20], y[0,:20], random_state=1, test_size=0.3)
x_train1, x_test1, y_train1, y_test1 = train_test_split(x[:20], y[1,:20], random_state=1, test_size=0.3)



# svr_rbf = SVR(kernel='rbf', gamma=0.1)
# svr_linear = SVR(kernel='linear')
# svr_poly0 = SVR(kernel='poly',gamma='auto',degree=3,tol=0.1)
# svr_poly1 = SVR(kernel='poly',gamma='auto',degree=3,tol=0.1)

svr_sig0 = SVR(kernel='sigmoid')
svr_sig1 = SVR(kernel='sigmoid')

svr_rbf0 = SVR(kernel='rbf')
svr_rbf1 = SVR(kernel='rbf')


# xgb_model = xgb.XGBRegressor(learning_rate=0.0001, n_estimators=1000)

def evaluate_model(name,model, x_train, y_train, x_test, y_test):
    print(name)
    start = time.time()
    model.fit(x_train, y_train)
    y_pred = model.predict(x_test)
    ypred_train = model.predict(x_train)
    print('MSE train', mean_absolute_error(y_train, ypred_train))
    print('MSE test', mean_absolute_error(y_test, y_pred))
    r_2 = model.score(x_test, y_test)
    print('R^2 test', r_2)
    print('Execution time: {0:.2f} seconds.'.format(time.time() - start))
    return r_2
    # print(name + '($R^2={:.3f}$)'.format(r_2), np.array(y_test), y_pred)

# evaluate_model("XGB",xgb_model,x_train,y_train,x_test,y_test)
# evaluate_model("SVR_poly0",svr_poly0,x_train0,y_train0,x_test0,y_test0)
# evaluate_model("SVR_poly1",svr_poly1,x_train1,y_train1,x_test1,y_test1)
evaluate_model("SVR_sig0",svr_sig0,x_train0,y_train0,x_test0,y_test0)
evaluate_model("SVR_sig1",svr_sig1,x_train1,y_train1,x_test1,y_test1)
evaluate_model("SVR_rbf0",svr_rbf0,x_train0,y_train0,x_test0,y_test0)
evaluate_model("SVR_rbf1",svr_rbf1,x_train1,y_train1,x_test1,y_test1)

# evaluate_model("SVR_rbf",svr_rbf,x_train,y_train,x_test,y_test)
# evaluate_model("SVR_linear",svr_linear,x_train,y_train,x_test,y_test)
# evaluate_model("SVR_sigmoid",svr_sig,x_train,y_train,x_test,y_test)

controllers_imitated = [SVRBoids.SVRBoids(svr_rbf0,svr_rbf1) for i in range(params.num_agents)]
for controller in controllers_imitated:
    controller.setColor('black')
agentPositions_imitated, agentVels_imitated = sim.runSim(controllers_imitated,params)
export.export(export.ExportType.GIF,"SVRImitated",agentPositions_imitated,agentVels_imitated,controllers=controllers_imitated,params=params,vision_mode=False)