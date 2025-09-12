import math
import os
import time
from threading import Thread
from threading import Event
import random
import subprocess

import sys

DESIRED_CUDA_LOOPS = 64

working_dir = './'

if len(sys.argv) != 2:
    print(f"Usage: python {sys.argv[0]} <JOB folder>")
    exit()
    
JOB_dir = sys.argv[1] + "/"
MAIN_LOG = f'{JOB_dir}/main.log'

from datetime import datetime
def log_str(logfile_name, string_to_log):
    with open(logfile_name, 'a') as f:
        now = datetime.now()
        dt_string = now.strftime("%d/%m/%Y %H:%M:%S")
        f.write(dt_string+': '+string_to_log+'\n')

def t_job(t_id, config, JOB_list, JB_ev):
    failsafe_file_closing_flag = 0
    while True:
            # Wait for JOB list became free to use
        log_str(MAIN_LOG, f'[{t_id}] Wait for JOB list became free to use')
        JB_ev.wait()
        log_str(MAIN_LOG, f'[{t_id}] Hope THE JOB list to use')
        JB_ev.clear()

        if(len([el for el in JOB_list if "(!) SOLUTION:[" in el]) > 0):
            log_str(MAIN_LOG, f'[{t_id}] ....THE JOB list is released to be used')
            JB_ev.set()
            log_str(MAIN_LOG, f'[{t_id}]: JOB list already store the SOLUTION, Thread terminated') 
            break

            # Take some yet unsolved task (step with "_" or "#" status)
        free_steps = [int(line.split('|')[0]) for line in JOB_list if line.split('|')[3]=="_"]
        
        if(len(free_steps) == 0):
            log_str(MAIN_LOG, f'[{t_id}] ....THE JOB list is released to be used')
            JB_ev.set()
            log_str(MAIN_LOG, f'[{t_id}]: JOB list is empty, Thread terminated') 
            break
        
        step =  random.choice(free_steps)
        step_parameters = JOB_list[step]
        JOB_list[step]= JOB_list[step][:-1]+"*"            
        with open(JOB_dir+"/"+'JOB_list.txt','w') as f:
            f.write('\n'.join(JOB_list))
        log_str(MAIN_LOG, f'[{t_id}] ....THE JOB list is released to be used')
        JB_ev.set()

        step_interval = int(step_parameters.split('|')[2])
        if step_interval < config['cuda_block_opt'][t_id]:
            cuda_block = step_interval
            cuda_grid = 1
            cuda_loops = 1            
        else:
            cuda_block = config['cuda_block_opt'][t_id]
            if math.ceil(step_interval / cuda_block) < config['cuda_grid_opt'][t_id]:
                cuda_grid  = math.ceil(step_interval / cuda_block)
                cuda_loops = 1
            else:
                cuda_grid = config['cuda_grid_opt'][t_id]
                if math.ceil(step_interval / (cuda_block*cuda_grid)) < DESIRED_CUDA_LOOPS:
                    cuda_loops = math.ceil(step_interval / (cuda_block*cuda_grid))
                else:
                    cuda_loops = DESIRED_CUDA_LOOPS

        arguments=[f"--cuda_device_id={config['cuda_ids'][t_id]}",
                   f"--cuda_grid={cuda_grid}",
                   f"--cuda_block={cuda_block}",
                   f"--loops_num={cuda_loops}",                   
                   f"--msg_file={config['msg_file']}",
                   f"--solution_tag={config['solution_tag']}",                   
                   f"--keys_file={config['keys_file']}",                  
                   f"--keys_num={config['keys_num']}",
                   f"--index_begin={step_parameters.split('|')[1]}",
                   f"--index_interval={step_parameters.split('|')[2]}",
                   f"--log_folder={JOB_dir}"]
        
        log_str(MAIN_LOG, f'[{t_id}]: begin step:{step} work. [{arguments}]') 
        
            # Create a subprocess and set up pipes for input and output
        process = subprocess.Popen([f"{working_dir}/cu_brute_ar"] + arguments, stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True)

            # Read the result from the subprocess
        result = process.stdout.read()
        process.stdout.close()  # Close the output pipe

            # Wait for the subprocess to complete
        exit_status = process.wait()
        log_str(MAIN_LOG, f'[{t_id}]:exit status is {exit_status}') 
        
            # Wait for JOB list became free to use
        log_str(MAIN_LOG, f'[{t_id}] Wait for JOB list became free to use')
        JB_ev.wait()
        log_str(MAIN_LOG, f'[{t_id}] Hope THE JOB list to use')
        JB_ev.clear()

        # HERE UPDATE JOB_list !!!!!!!!!!!!!!1
        if   (exit_status == 0):
            JOB_list[step]= JOB_list[step][:-1]+'@'
        elif (exit_status == 1):
            JOB_list[step]= JOB_list[step][:-1]+'@'+"(!) SOLUTION:["+result.strip('\n').replace('\n',' ')+"]"
            log_str(MAIN_LOG, f'[{t_id}] Solution FOUND: [{result.replace('\n',' ')}]')
        else:
            JOB_list[step]= JOB_list[step][:-1]+'#'+result.replace('\n',' ')
        with open(JOB_dir+"/" + 'JOB_list.txt','w') as f:
            f.write('\n'.join(JOB_list))

        log_str(MAIN_LOG, f'[{t_id}] ....THE JOB list is released to be used')
        JB_ev.set()
        
            
        with open(JOB_dir+"/"+'failsafe.txt', 'r') as f:
            failsafe_file_closing_flag = int(next(f))
                
        if failsafe_file_closing_flag:
            log_str(MAIN_LOG, f'[{t_id}] Finishing by failsafe')
            break



with open(JOB_dir +"/"+ "JOB.cfg", "r") as file:
    lines_data = [line.strip('\n').split('=')[1] for line in file.readlines()]   
 
config = {};
config['cuda_ids']         = [int(n) for n in lines_data[0].split(',')]
config['cuda_grid_opt']    = [int(n) for n in lines_data[1].split(',')]
config['cuda_block_opt']   = [int(n) for n in lines_data[2].split(',')]
config['msg_file']         = JOB_dir + "/" + lines_data[3]
config['solution_tag']     = lines_data[4]
config['keys_file']        = JOB_dir + "/" + lines_data[5]
config['keys_num']         = lines_data[6]
single_thread_speeds       = [int(n) for n in lines_data[7].split(',')]
average_step_duration_sec  = int(lines_data[8])

if (os.path.isfile(config['keys_file'])):
    with open(config['keys_file'],'r') as f:
        key_words = [l.strip().split(',') for l in f.read().strip().split('\n')]
else:
    print(f"ERROR: {config['keys_file']} not found\n")
    sys.exit()

    # Read or Compose the JOB list (plan). 
    # "step id|index entry|index interval|status
    # status: "_" - fresh\not tried, "*" - in progress (brute is ongoing), "#" - error\fail happen,
    # "numbers" - result of brute.
    # (blank all "*" on fresh start - assuming previous brute has not returned their last results successfully
    # and it should be redone)
if (os.path.isfile(JOB_dir+"/"+'JOB_list.txt')):
    with open(JOB_dir+"/"+'JOB_list.txt','r') as f:
        JOB_list = ['|'.join([line.split('|')[0],line.split('|')[1],line.split('|')[2],"_"]) if ((line.split('|')[3]=='*') or (line.split('|')[3][0]=='#')) else line  for line in  f.read().strip().split('\n')]
else:
    full_indecies_interval = math.prod([len(k) for k in key_words])


    actual_max_speed = max( [ single_thread_speeds[i] * config['cuda_grid_opt'][i]  * config['cuda_block_opt'][i] for i in range(len(config['cuda_ids']))] )

    step_interval = math.ceil( average_step_duration_sec * actual_max_speed / (DESIRED_CUDA_LOOPS*max( [ config['cuda_grid_opt'][i]  * config['cuda_block_opt'][i] for i in range(len(config['cuda_ids']))] )) )

    step_interval = step_interval *DESIRED_CUDA_LOOPS* max( [ config['cuda_grid_opt'][i]  * config['cuda_block_opt'][i] for i in range(len(config['cuda_ids']))] )
    steps_number = math.ceil(full_indecies_interval / step_interval)

    intervals = [ [i*step_interval, min( (i+1)*step_interval, full_indecies_interval )] for i in range(steps_number)]
    
    JOB_list = [ str(i)+"|"+str(i*step_interval)+"|"+str(intervals[i][1]-intervals[i][0])+"|"+"_" for i in range(steps_number)]
    with open(JOB_dir+"/" + 'JOB_list.txt','w') as f:
        f.write('\n'.join(JOB_list))

    # Preapare the semaphore for JOB list
JB_ev = Event()
JB_ev.set()



    # Prepare the failsafe shutdown file (1 written there triggers threads to stop)
with open(JOB_dir+"/"+'failsafe.txt', 'w') as f:
    f.write('%d' % 0)

t_num = len(config['cuda_ids'])
t = [0] * t_num
    
for i in range(t_num):
    t[i] = Thread(target = t_job, args=(i, config, JOB_list, JB_ev) )
    t[i].start()
    time.sleep(3)
    
for i in range(t_num):
    t[i].join()
       
print('FINISH')
