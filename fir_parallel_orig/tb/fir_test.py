from scipy.signal import lfilter
import numpy as np


def gen_filter():
    from scipy import signal
    
    cutoff = .1       # Desired passband bandwidth Hz
    trans_width = .3  # Width of transition from pass to stop Hz
    numtaps = 3       # Size of the FIR filter. # MOD
    fs = 1            # normalized sampling rate

    # floating point coefficients
    filter_coefs = signal.remez(numtaps, [0, cutoff, cutoff + trans_width, 0.5*fs],[1, 0], fs=fs)

    # 4 bit integer coefficients
    filter_coefs_int = np.round(filter_coefs * (2**3-1)) # MOD
    
    print(filter_coefs_int)
    
    return(filter_coefs_int)

def wave(amp, f, fs, clks): 
    clks = np.arange(0, clks)
    sample = np.rint(amp*np.sin(2.0*np.pi*f/fs*clks))
    return sample

def predictor(signal,coefs):
    output = lfilter(coefs,1.0,signal)
    return output

def stimulus_generator():
    #initialize
    fs       = 1
    amp0     = 10 # MOD
    num_clks = 512
    f0       = 50*(1.0/num_clks)
    coeffs   = gen_filter()
    cnt      = 0

    # input data
    input_signal = wave(amp0, f0, fs,num_clks) + wave(amp0/2, 200.5*(1.0/num_clks), fs, num_clks)

    # bit accurate predictor values
    data_out_pred = predictor(input_signal, coeffs)
    
    print("Input: ", end=' ')
    for data in input_signal:
        print(data, end=',')
        
    print("Output: ", end=' ')
    for data in data_out_pred:
        print(data, end=',')
        
if __name__ == "__main__":
    stimulus_generator()