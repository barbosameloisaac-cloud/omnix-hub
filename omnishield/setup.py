"""OmniShield setup script for cross-platform installation."""

from setuptools import find_packages, setup

from omnishield import __version__

setup(
    name="omnishield",
    version=__version__,
    description="Cross-Platform Futuristic Antivirus Engine",
    long_description=open("../README.md").read() if __name__ == "__main__" else "",
    long_description_content_type="text/markdown",
    author="OmniShield Team",
    license="MIT",
    packages=find_packages(),
    include_package_data=True,
    package_data={
        "omnishield": [
            "ui/**/*",
            "signatures/*.json",
        ],
    },
    python_requires=">=3.9",
    install_requires=[
        "fastapi>=0.104.0",
        "uvicorn[standard]>=0.24.0",
        "watchdog>=3.0.0",
        "pydantic>=2.0.0",
    ],
    entry_points={
        "console_scripts": [
            "omnishield=omnishield.main:main",
        ],
    },
    classifiers=[
        "Development Status :: 4 - Beta",
        "Environment :: Console",
        "Environment :: Web Environment",
        "Intended Audience :: End Users/Desktop",
        "License :: OSI Approved :: MIT License",
        "Operating System :: OS Independent",
        "Programming Language :: Python :: 3",
        "Programming Language :: Python :: 3.9",
        "Programming Language :: Python :: 3.10",
        "Programming Language :: Python :: 3.11",
        "Programming Language :: Python :: 3.12",
        "Topic :: Security",
    ],
)
