# pylint: disable=missing-class-docstring,invalid-name,missing-function-docstring
import torch.nn as nn
import torch.nn.functional as F

class MNISTLeNet5(nn.Module):
    def __init__(self):
        super().__init__()
        self.features = nn.Sequential(
            nn.Conv2d(1, 6, kernel_size=5),
            nn.Tanh(),
            nn.MaxPool2d(kernel_size=2),
            nn.Conv2d(6, 16, kernel_size=5),
            nn.Tanh(),
            nn.MaxPool2d(kernel_size=2)
        )

        self.classifier = nn.Sequential(
            nn.Flatten(),
            nn.Linear(256, 120),
            nn.Tanh(),
            nn.Linear(120, 84),
            nn.Tanh(),
            nn.Linear(84, 10),
        )

    def forward(self, x): # pylint: disable=missing-function-docstring
        x = self.features(x)
        x = self.classifier(x)
        return F.softmax(x, dim=1)
