%generate_input.m
%Sam Gallager
%12 Feb 2016
%
%This function generates a random input to work with an HTM CLA learning
%algorithm designed either in matlab or elsewhere. The output is saved in a
%file with the extension .htm

function input = generate_input()
    input = randi(2,100,10)-1;
    save input.htm input -ascii;
end