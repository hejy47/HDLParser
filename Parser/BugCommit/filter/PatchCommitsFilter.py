import os
import shutil
from BugCommit.parser.MessageFile import MessageFile
from utils import DiffByGumTree
import Configuration

def filter(subjectsPath, outputPath):
    diffArr = DiffByGumTree.getGumTreeDiff()
    projects = os.listdir(subjectsPath)
    for project in projects:
        print("Filtering "+project)
        msgFiles = readMessageFiles(project, outputPath)
        total = len(msgFiles)
        parseError = 0
        parseEmpty = 0
        selectedCommits = []
        for msgFile in msgFiles:
            revFile = msgFile.getRevFile()
            prevFile = msgFile.getPrevFile()
            diffentryFile = msgFile.getDiffEntryFile()
            if not os.path.exists(revFile) or not os.path.exists(prevFile) or not os.path.exists(diffentryFile):
                total -= 1
                continue
            diffActions = DiffByGumTree.diff(prevFile, revFile, diffArr)
            if diffActions == None:
                parseError += 1
                total -= 1
                shutil.rmtree(os.path.dirname(prevFile))
                shutil.rmtree(os.path.dirname(revFile))
                os.remove(diffentryFile)
            elif len(diffActions) == 0:
                parseEmpty += 1
                total -= 1
                shutil.rmtree(os.path.dirname(prevFile))
                shutil.rmtree(os.path.dirname(revFile))
                os.remove(diffentryFile)
            else:
                selectedCommit = os.path.basename(revFile)[:17]
                if selectedCommit not in selectedCommits:
                    selectedCommits.append(selectedCommit)
        print("All MSGFiles:", total+parseError+parseEmpty)
        print("Parse Error MSGFiles:", parseError)
        print("Parse Empty MSGFiles:", parseEmpty)
        print("Selected MSGFiles:", total)
        print("Selected Commits:", len(selectedCommits), "\n")

# def filter(project, outputPath, diffArr):
#     print("Filtering "+project)
#     msgFiles = readMessageFiles(project, outputPath)
#     total = len(msgFiles)
#     parseError = 0
#     parseEmpty = 0
#     selectedCommits = []
#     print(project, "All MSGFiles:", total)
#     for msgFile in msgFiles:
#         revFile = msgFile.getRevFile()
#         prevFile = msgFile.getPrevFile()
#         diffentryFile = msgFile.getDiffEntryFile()
#         diffActions = DiffByGumTree.diff(prevFile, revFile, diffArr)
#         if diffActions == None:
#             parseError += 1
#             total -= 1
#             shutil.rmtree(os.path.dirname(prevFile))
#             shutil.rmtree(os.path.dirname(revFile))
#             os.remove(diffentryFile)
#         elif len(diffActions) == 0:
#             parseEmpty += 1
#             total -= 1
#             shutil.rmtree(os.path.dirname(prevFile))
#             shutil.rmtree(os.path.dirname(revFile))
#             os.remove(diffentryFile)
#         else:
#             selectedCommit = os.path.basename(revFile)[:17]
#             if selectedCommit not in selectedCommits:
#                 selectedCommits.append(selectedCommit)
#     print(project, "Parse Error MSGFiles:", parseError)
#     print(project, "Parse Empty MSGFiles:", parseEmpty)
#     print(project, "Selected MSGFiles:", total)
#     print(project, "Selected Commits:", len(selectedCommits), "\n")

def readMessageFiles(projectName, path):
    msgFiles = []
    keywordPatchesFile = os.path.join(path, "Keywords", projectName)
    commitIds = []

    msgFiles = msgFiles + getMessageFiles(keywordPatchesFile, commitIds)
    return msgFiles

def getMessageFiles(projectPath, commitIds):
    msgFiles = []
    revFilesPath = os.path.join(projectPath, "revFiles")
    prevFilesPath = os.path.join(projectPath, "prevFiles")
    diffentryFilesPath = os.path.join(projectPath, "DiffEntries")
    if not os.path.exists(revFilesPath):
        return []
    revFilesSubPath = os.listdir(revFilesPath)
    for revFileSubPath in revFilesSubPath:
        prevFileSubPath = "prev_" + revFileSubPath
        diffentryFile = revFileSubPath + ".txt"
        revFilePath = os.path.join(revFilesPath, revFileSubPath, revFileSubPath)
        prevFilePath = os.path.join(prevFilesPath, prevFileSubPath, prevFileSubPath)
        for hdlType in [".v", ".vhd", ".vhdl", ".sv"]:
            if os.path.exists(revFilePath+hdlType) and os.path.exists(prevFilePath+hdlType):
                revFilePath = revFilePath+hdlType
                prevFilePath = prevFilePath+hdlType
                break
        msgFile = MessageFile(revFilePath, prevFilePath,\
            os.path.join(diffentryFilesPath, diffentryFile))
        msgFiles.append(msgFile)
        commitId = revFileSubPath[:8]
        if commitId not in commitIds: commitIds.append(commitId)
    return msgFiles