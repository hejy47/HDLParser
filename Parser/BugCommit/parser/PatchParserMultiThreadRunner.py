import threading
import Configuration
from BugCommit.parser import PatchParserRunner
from utils import FileHelper, DiffByGumTree

class RepoThread(threading.Thread):
    def __init__(self, repoName, msgFiles, diffArr, outputPath):
        threading.Thread.__init__(self)
        self.repoName = repoName
        self.msgFiles = msgFiles
        self.diffArr = diffArr
        self.outputPath = outputPath

    def run(self) -> None:
        print("Starting ", self.repoName)
        PatchParserRunner.parse(self.repoName, self.msgFiles, self.diffArr, self.outputPath)
        print("Exiting ", self.repoName)

def run(patchPath, outputPath):
    FileHelper.deleteDirectory(Configuration.REDUNDANCY_PATH)
    diffArr = DiffByGumTree.getGumTreeDiff()
    msgFiles = PatchParserRunner.readMessageFiles(patchPath, "Keywords")
    for repoName, repoMsgFiles in msgFiles.items():
        # if repoName not in ["hdl"]: continue
        repoThread = RepoThread(repoName, repoMsgFiles, diffArr, outputPath)
        repoThread.start()