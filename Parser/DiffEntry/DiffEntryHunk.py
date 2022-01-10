class DiffEntryHunk():
    def __init__(self, commitId, commitMessage, diffFile, bugLineStartNum, fixLineStartNum, bugRange, fixRange) -> None:
        self.commitId = commitId
        self.commitMessage = commitMessage
        self.diffFile = diffFile
        self.bugLineStartNum = bugLineStartNum
        self.fixLineStartNum = fixLineStartNum
        self.bugRange = bugRange
        self.fixRange = fixRange
        self.diffEntryHunkContent = ""
        self.buggyHunkSize = 0
        self.fixedHunkSize = 0

    def getBugLineStartNum(self):
        return self.bugLineStartNum
    
    def getFixLineStartNum(self):
        return self.fixLineStartNum
    
    def getBugRange(self):
        return self.bugRange
    
    def getFixRange(self):
        return self.fixRange
    
    def getCommitId(self):
        return self.commitId
    
    def getCommitMessage(self):
        return self.commitMessage
    
    def getDiffFile(self):
        return self.diffFile

    def getDiffEntryHunkContent(self):
        return self.diffEntryHunkContent

    def setDiffEntryHunkContent(self, diffEntryHunkContent):
        self.diffEntryHunkContent = diffEntryHunkContent
    
    def getBuggyHunkSize(self):
        return self.buggyHunkSize
    
    def setBuggyHunkSize(self, buggyHunkSize):
        self.buggyHunkSize = buggyHunkSize
    
    def getFixedHunkSize(self):
        return self.fixedHunkSize
    
    def setFixedHunkSize(self, fixedHunkSize):
        self.fixedHunkSize = fixedHunkSize