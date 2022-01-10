from GumTreeAction.HierarchicalActionSet import HierarchicalActionSet
from utils import DiffByGumTree
from utils import FileHelper
from GumTreeAction import HierarchicalRegrouper, CodeCloneAnalyzer

class PatchParser():
    def __init__(self) -> None:
        self.hunks = 0
        self.diffs = 0
        self.zeroG = 0
        self.overRap = 0
        self.patches = {}
        self.selectedCommitIds = []
        self.codeEntityRedundancyNumForLocal = 0
        self.codeEntitySumForLocal = 0
        self.fileRedundancyForLocal = False
        self.codeEntityRedundancyNumForGlobal = 0
        self.codeEntitySumForGlobal = 0
        self.fileRedundancyForGlobal = False
    
    def parsePatches(self, prevFile, revFile, diffentryFile, diffArr, bugHunkSize=1000, fixHunkSize=1000):
        actionSets = self.parseChangedSourceCodeWithGumTree(prevFile, revFile, diffArr)
        # filter the result
        if actionSets != None and len(actionSets) > 0:
            diffentryHunks = FileHelper.readDiffEntryHunks(diffentryFile)
            self.hunks = len(diffentryHunks)
            for hunk in diffentryHunks:
                buggyHunkSize = hunk.getBuggyHunkSize()
                fixedHunkSize = hunk.getFixedHunkSize()
                if buggyHunkSize <= bugHunkSize and fixedHunkSize <= fixHunkSize:
                    self.diffs += 1
                    commitId = hunk.getCommitId()
                    if commitId not in self.selectedCommitIds:
                        self.selectedCommitIds.append(commitId)

                    buggyStart = hunk.getBugLineStartNum()
                    fixedStart = hunk.getFixLineStartNum()
                    buggyRange = hunk.getBugRange()
                    fixedRange = hunk.getFixRange()
                    buggyEnd = (buggyStart + buggyRange) if buggyRange == 0 else (buggyStart + buggyRange - 1)
                    fixedEnd = (fixedStart + fixedRange) if fixedRange == 0 else (fixedStart + fixedRange - 1)
                    
                    singlePatch = HierarchicalActionSet(None, None, None, None)

                    for actionSet in actionSets:
                        self.setLineNumbers(actionSet, prevFile, revFile)
                        actionBugStartLine = actionSet.getBugStartLineNum()
                        actionBugEndLine = actionSet.getBugEndLineNum()
                        actionFixStartLine = actionSet.getFixStartLineNum()
                        actionFixEndLine = actionSet.getFixEndLineNum()

                        actionStr = str(actionSet.getAction().getName())
                        if actionStr.startswith("insert"):
                            if fixedStart <= actionFixEndLine and actionFixStartLine <= fixedEnd:
                                singlePatch.addSubAction(actionSet)
                        else:
                            if buggyStart <= actionBugEndLine and actionBugStartLine <= buggyEnd:
                                singlePatch.addSubAction(actionSet)
                    
                    if len(singlePatch.getSubActions()) > 0:
                        self.addToPatchesMap(singlePatch, hunk)

    def setLineNumbers(self, actionSet, prevFile, revFile):
        prevF = open(prevFile, 'r')
        revF = open(revFile, 'r')
        prevContent = prevF.read()
        revContent = revF.read()

        bugStartPosition, bugEndPosition = 0, 0
        fixStartPosition, fixEndPosition = 0, 0
        actionType = str(actionSet.getAction().getName())
        if actionType.startswith("insert"):
            newTree = actionSet.getNode()
            fixStartPosition = newTree.getPos()
            fixEndPosition = newTree.getEndPos()
        else:
            newTree = actionSet.getNode()
            bugStartPosition = newTree.getPos()
            bugEndPosition = newTree.getEndPos()
        actionStartLine, actionEndLine = 0, 0
        if bugStartPosition > 0:
            actionStartLine = prevContent.count('\n', 0, bugStartPosition) + 1
            actionEndLine = prevContent.count('\n', 0, bugEndPosition) + 1
        elif fixStartPosition > 0:
            actionStartLine = revContent.count('\n', 0, fixStartPosition) + 1
            actionEndLine = revContent.count('\n', 0, fixEndPosition) + 1
        actionSet.setBugStartLineNum(actionStartLine)
        actionSet.setFixStartLineNum(actionStartLine)
        actionSet.setBugEndLineNum(actionEndLine)
        actionSet.setFixEndLineNum(actionEndLine)

        prevF.close()
        revF.close()

    def addToPatchesMap(self, singlePatch, hunk):
        p = self.patches.get(hunk, None)
        if p == None:
            p = [singlePatch]
            self.patches[hunk] = p
        else:
            p.append(singlePatch)

    def parseChangedSourceCodeWithGumTree(self, prevFile, revFile, diffArr):
        actionSets = []
        gumTreeResults = self.compareTwoFilesWithGumTree(prevFile, revFile, diffArr)
        if gumTreeResults == None or len(gumTreeResults) == 0:
            return actionSets
        else:
            # self.codeEntityRedundancyNumForLocal, self.codeEntitySumForLocal, self.fileRedundancyForLocal = CodeCloneAnalyzer.getFileRedundancy(gumTreeResults, prevFile, diffArr, "Statement", "Local")
            # self.codeEntityRedundancyNumForGlobal, self.codeEntitySumForGlobal, self.fileRedundancyForGlobal = CodeCloneAnalyzer.getFileRedundancy(gumTreeResults, prevFile, diffArr, "Statement", "Global")
            allActionSets = HierarchicalRegrouper.regroupGumTreeResults(gumTreeResults)
            # allActionSets.sort(key=lambda x:x.startPostion)
            return allActionSets
    
    def parsePatchesForRedundancy(self, prevFile, revFile, diffArr, level):
        gumTreeResults = self.compareTwoFilesWithGumTree(prevFile, revFile, diffArr)
        if gumTreeResults == None or len(gumTreeResults) == 0:
            pass
        else:
            self.codeEntityRedundancyNumForLocal, self.codeEntitySumForLocal, self.fileRedundancyForLocal = CodeCloneAnalyzer.getFileRedundancy(gumTreeResults, prevFile, diffArr, level, "Local")
            self.codeEntityRedundancyNumForGlobal, self.codeEntitySumForGlobal, self.fileRedundancyForGlobal = CodeCloneAnalyzer.getFileRedundancy(gumTreeResults, prevFile, diffArr, level, "Global")

    def compareTwoFilesWithGumTree(self, prevFile, revFile, diffArr):
        # command = ["gumtree", "textdiff", prevFile, revFile]
        # ret = subprocess.run(command, capture_output=True)
        # textDiff = ret.stdout
        diffActions = DiffByGumTree.diff(prevFile, revFile, diffArr)
        return diffActions
    
    def getPatches(self):
        return self.patches
    
    def getSelectedCommitIds(self):
        return self.selectedCommitIds
    
    def getRedundancy(self):
        return self.codeEntityRedundancyNumForLocal, self.codeEntitySumForLocal, self.fileRedundancyForLocal,\
            self.codeEntityRedundancyNumForGlobal, self.codeEntitySumForGlobal, self.fileRedundancyForGlobal