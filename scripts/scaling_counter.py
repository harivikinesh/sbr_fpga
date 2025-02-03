
import math

def find_exponent(number):
    if number <= 0:
        raise ValueError("Number must be greater than 0")
    
    # Calculate the base-2 logarithm of the number
    x = math.log2(number)
    
    # Since we need 2^x to be greater than the number, we take the ceiling of the logarithm
    return math.ceil(x)

print("Gives you counter value for scaling higher frequency to lower")
input_clk = float(input("Enter input frequency (clk_1) in MHz: "))
scaled_clk = float(input("Enter expected frequency (clk_2) in MHz: "))

counter_val = (input_clk/scaled_clk) / 2

print("counter value for frequency scaling is {:.2f}".format(counter_val))

print("=================================================================")
print("Code\n")

print("reg [{:d}:0] counter;\n".format(int(find_exponent(counter_val))))
print("always @(posedge clk_1) begin")
print("\tif (counter == {:d}) begin".format(int(counter_val)))
print("\t\tclk_2 = ~clk_2; counter = 0;")
print("\tend")
print("\telse counter = counter+1'b1;")
print("end\n")

print("=================================================================")

