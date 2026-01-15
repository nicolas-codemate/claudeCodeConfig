#!/usr/bin/env node

const { exec } = require('child_process');
const { existsSync } = require('fs');
const os = require('os');
const path = require('path');

// Get command line argument for sound type
const soundType = process.argv[2] || 'default';

// Get sound file path
function getSoundFile(type = 'default') {
  const homeDir = os.homedir();
  
  const sounds = {
    default: path.join(homeDir, 'Music', 'default.mp3'),
    notification: path.join(homeDir, 'Music', 'notification.mp3'),
    done: path.join(homeDir, 'Music', 'done.mp3'),
  };
  
  return sounds[type] || sounds.default;
}

// Play the sound
function playSound() {
  const soundFile = getSoundFile(soundType);
  
  if (!existsSync(soundFile)) {
    if (process.env.DEBUG) {
      console.error(`Sound file not found: ${soundFile}`);
    }
    return;
  }
  
  const command = `ffplay -nodisp -autoexit -v quiet "${soundFile}"`;
  
  if (process.env.DEBUG) {
    console.error(`Playing sound: ${soundType}`);
    console.error(`Command: ${command}`);
  }
  
  exec(command, { timeout: 5000 }, (error) => {
    if (error && process.env.DEBUG) {
      console.error(`Error playing sound: ${error.message}`);
    }
  });
}

// Run the script
playSound();