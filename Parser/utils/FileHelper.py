import os
import shutil

from git import exc
from DiffEntry.DiffEntryHunk import DiffEntryHunk

def getAllFiles(filePath):
    if not os.path.exists(filePath):
        return None
    fileList = []
    if os.path.isfile(filePath) and (filePath.endswith(".v") or filePath.endswith(".vhd") or filePath.endswith(".vhdl") or filePath.endswith(".sv")):
        fileList.append(filePath)
    if os.path.isdir(filePath) and not os.path.islink(filePath):
        files = os.listdir(filePath)
        for f in files:
            fPath = os.path.join(filePath, f)
            fl = getAllFiles(fPath)
            if fl != None: fileList.extend(fl)
    return fileList

def creatCSV(fileName, fileContent):
    parentDirectory = os.path.dirname(fileName)
    if not os.path.exists(parentDirectory):
        os.makedirs(parentDirectory)
    fileContent.to_csv(fileName)

def creatFile(fileName, fileContent):
    parentDirectory = os.path.dirname(fileName)
    if not os.path.exists(parentDirectory):
        os.makedirs(parentDirectory)
    with open(fileName, 'w') as f:
        try:
            f.write(fileContent)
        except:
            print("write error")

def deleteFile(filePath):
    if os.path.exists(filePath) and os.path.isfile(filePath):
        os.remove(filePath)

def deleteDirectory(dir):
    if os.path.exists(dir):
        shutil.rmtree(dir)

def copyFile(srcFilePath, dstFilePath):
    if os.path.exists(srcFilePath) and os.path.isfile(srcFilePath):
        shutil.copyfile(srcFilePath, dstFilePath)

def copyDirectory(srcDir, dstDir):
    if os.path.isdir(dstDir):
        deleteDirectory(dstDir)
    if os.path.exists(srcDir) and os.path.isdir(srcDir):
        shutil.copytree(srcDir, dstDir)

def readDiffEntryHunks(diffentryFile):
    diffEntryHunks = []
    with open(diffentryFile, 'r') as f:
        content = f.readlines()
        if len(content) == 0:
            return []
        commitId = content[0]
        commitMessage = content[1]
        diffFile = content[4:6]
        diffContent = content[6:]
        hunkContents = []
        hunkContent = []
        for line in diffContent:
            if line.startswith("@@") and len(hunkContent) != 0:
                hunkContents.append(hunkContent)
                hunkContent = [line]
            else: hunkContent.append(line)
        if len(hunkContent) != 0: hunkContents.append(hunkContent)
        for hunkContent in hunkContents:
            line = hunkContent[0]
            buggyStartLine, buggyRange, buggyHunkSize = 0, 0, 0
            fixedStartLine, fixedRange, fixedHunkSize = 0, 0, 0
            if line.startswith("@@"):
                plusIndex = line.find("+")
                lineNum = line[4:plusIndex-1]
                nums = lineNum.split(",")
                buggyStartLine = eval(nums[0])
                if (len(nums) == 2):
                    buggyRange = eval(nums[1])
                
                lastIndex = line.rfind("@@")
                lineNum2 = line[plusIndex:lastIndex-1]
                nums2 = lineNum2.split(",")
                fixedStartLine = eval(nums2[0])
                if (len(nums2) == 2):
                    fixedRange = eval(nums2[1])
            for l in hunkContent[1:]:
                if l.startswith("-"):
                    buggyHunkSize += 1
                elif l.startswith("+"):
                    fixedHunkSize += 1
                
            diffEntryHunk = DiffEntryHunk(commitId, commitMessage, diffFile, buggyStartLine, fixedStartLine, buggyRange, fixedRange)
            diffEntryHunk.setDiffEntryHunkContent("".join(hunkContent))
            diffEntryHunk.setBuggyHunkSize(buggyHunkSize)
            diffEntryHunk.setFixedHunkSize(fixedHunkSize)
            diffEntryHunks.append(diffEntryHunk)
    return diffEntryHunks