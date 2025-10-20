from setuptools import setup, find_packages

with open("README.md", "r", encoding="utf-8") as fh:
    long_description = fh.read()

setup(
    name="parametrizacion_emaku_lacali",
    version="0.1.0",
    author="Your Name",
    author_email="your.email@example.com",
    description="Parametrización del sistema EMK para lacali",
    long_description=long_description,
    long_description_content_type="text/markdown",
    url="https://github.com/yourusername/parametrizacion_emaku_lacali",
    packages=find_packages(exclude=["tests*"]),
    package_data={
        "": ["*.xml", "*.sql"],
    },
    classifiers=[
        "Programming Language :: Python :: 3",
        "License :: OSI Approved :: MIT License",
        "Operating System :: OS Independent",
    ],
    python_requires=">=3.8",
    install_requires=[
        "psycopg2-binary>=2.9.3",
        "python-dotenv>=0.19.0",
        "lxml>=4.6.3",
    ],
    extras_require={
        "dev": [
            "black>=21.12b0",
            "flake8>=4.0.1",
            "isort>=5.10.1",
            "pre-commit>=2.16.0",
        ],
        "test": [
            "pytest>=6.2.5",
            "pytest-cov>=2.12.1",
        ],
        "docs": [
            "sphinx>=4.2.0",
            "sphinx-rtd-theme>=1.0.0",
        ],
    },
    entry_points={
        "console_scripts": [
            # Add any command-line tools here
            # 'command-name = module:function',
        ],
    },
)
