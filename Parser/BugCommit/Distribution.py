import os
import pandas as pd
from utils import FileHelper

def countLOC(subjectsPath):
    projects = os.listdir(subjectsPath)
    for project in projects:
        projectPath = os.path.join(subjectsPath, project)
        if os.path.isdir(projectPath):
            allVerilogFiles = FileHelper.getAllFiles(projectPath)
            
            counter = 0
            for verilogFile in allVerilogFiles:
                fileLowerName = verilogFile.lower()
                if "tb" in fileLowerName or "test" in fileLowerName or "testbench" in fileLowerName:
                    continue
                reader = open(verilogFile, 'r', errors="ignore")
                fileContent = reader.readlines()
                counter += len(fileContent)
            print(project, " LOC: ", counter)

def statistics(inputPath, outputPath):
    dataTypes = os.listdir(inputPath)
    diffentryRangeName = ["Hunk_Type", "Size"]
    diffentryRange = []
    buggyHunkSizes = []
    fixedHunkSizes = []
    for dataType in dataTypes:
        if os.path.isdir(os.path.join(inputPath, dataType)):
            projects = os.listdir(os.path.join(inputPath, dataType))
            for project in projects:
                projectPath = os.path.join(inputPath, dataType, project)
                if os.path.isdir(projectPath):
                    diffentryFiles = os.listdir(os.path.join(projectPath, "DiffEntries"))
                    for diffentryFile in diffentryFiles:
                        diffentryFilePath = os.path.join(projectPath, "DiffEntries", diffentryFile)
                        if os.path.isfile(diffentryFilePath) and diffentryFilePath.endswith(".txt"):
                            diffentryHunks = FileHelper.readDiffEntryHunks(diffentryFilePath)
                            for hunk in diffentryHunks:
                                bugRange = hunk.getBugRange()
                                fixRange = hunk.getFixRange()
                                buggyHunkSizes.append(bugRange)
                                fixedHunkSizes.append(fixRange)
                                diffentryRange.append(["Buggy_Hunk", str(bugRange)])
                                diffentryRange.append(["Fixed_Hunk", str(fixRange)])
    diffEntryRange = pd.DataFrame(columns=diffentryRangeName, data=diffentryRange)
    FileHelper.creatCSV(os.path.join(outputPath, "DiffEntryRange.csv"), diffEntryRange)
    summary(buggyHunkSizes, "buggy hunk")
    summary(fixedHunkSizes, "fixed hunk")

def summary(sizes, type):
    sizes.sort()

    size = len(sizes)
    firstQuaterIndex = size // 4
    firstQuater = sizes[firstQuaterIndex]
    thirdQuaterIndex = size * 3 // 4
    thirdQuater = sizes[thirdQuaterIndex]
    upperWhisker = thirdQuater + (thirdQuater - firstQuater) * 3 // 2
    maxSize = sizes[-1]
    upperWhisker = maxSize if upperWhisker > maxSize else upperWhisker

    print("Summary", type, "sizes:")
    print("Min:", sizes[0])
    print("First quartile:", firstQuater)
    print("Mean:", sum(sizes) / size)
    print("Third quartile:", thirdQuater)
    print("Upper whisker:", upperWhisker)
    print("Max:", maxSize)
