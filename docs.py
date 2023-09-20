import os

path = "docs"
files = []
# r=root, d=directories, f = files
for r, d, f in os.walk(path):
    for file in f:
        if '.md' in file:
            files.append(os.path.join(r, file))

for f in files:
    file = open(f, "r")
    lines = file.readlines()
    file.close()
    for i in range(len(lines)):
        if lines[i].startswith("function "):
            lines[i] = lines[i].replace("(", "(\n    ", 1).replace(")", "\n)", 1).replace(", ", ",\n    ").replace("struct ", "").replace("(\n    \n)", "()")
    with open(f, "w") as newfile:
        for line in lines:
            newfile.write(line)