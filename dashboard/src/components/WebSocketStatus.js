import React from 'react';
import './WebSocketStatus.css';

function WebSocketStatus({ connected }) {
  return (
    <div className={`ws-status ${connected ? 'connected' : 'disconnected'}`}>
      <span className="ws-indicator"></span>
      <span className="ws-text">
        {connected ? 'Live Updates Active' : 'Connecting...'}
      </span>
    </div>
  );
}

export default WebSocketStatus;
