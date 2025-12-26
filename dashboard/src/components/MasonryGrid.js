import React, { useEffect, useState } from 'react';
import './MasonryGrid.css';

const MasonryGrid = ({ children, columns = 3, gap = 16 }) => {
  const [columnCount, setColumnCount] = useState(columns);

  // Update column count based on viewport width
  useEffect(() => {
    const updateColumns = () => {
      const width = window.innerWidth;
      if (width < 640) {
        setColumnCount(1);
      } else if (width < 1024) {
        setColumnCount(2);
      } else {
        setColumnCount(columns);
      }
    };

    updateColumns();
    window.addEventListener('resize', updateColumns);
    return () => window.removeEventListener('resize', updateColumns);
  }, [columns]);

  // Distribute children into columns
  const getColumns = () => {
    const cols = Array.from({ length: columnCount }, () => []);
    children.forEach((child, index) => {
      cols[index % columnCount]?.push(child);
    });
    return cols;
  };

  const columnElements = getColumns();

  return (
    <div className="masonry-container">
      <div
        className="masonry-grid"
        style={{
          gridTemplateColumns: `repeat(${columnCount}, 1fr)`,
          gap: `${gap}px`,
        }}
      >
        {columnElements.map((column, columnIndex) => (
          <div key={columnIndex} className="masonry-column">
            {column.map((child, itemIndex) => (
              <div key={`${columnIndex}-${itemIndex}`} className="masonry-item">
                {child}
              </div>
            ))}
          </div>
        ))}
      </div>
    </div>
  );
};

export default MasonryGrid;
