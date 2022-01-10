class MessageFile():
    def __init__(self, revFile, prevFile, diffEntryFile) -> None:
        self.revFile = revFile
        self.prevFile = prevFile
        self.diffEntryFile = diffEntryFile
    
    def getRevFile(self):
        return self.revFile
    
    def getPrevFile(self):
        return self.prevFile
    
    def getDiffEntryFile(self):
        return self.diffEntryFile