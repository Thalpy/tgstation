import { round } from 'common/math';
import { AnimatedNumber, Box, Flex, Tooltip } from '../../components';

export const BeakerContents = props => {
  const { beakerLoaded, beakerContents } = props;
  let offset = 0;
  const incrementOffset = increment => {
    offset += increment;
  };
  return (
    <Box>
      {!beakerLoaded && (
        <Box color="label">
          No beaker loaded.
        </Box>
      ) || beakerContents.length === 0 && (
        <Box color="label">
          Beaker is empty.
        </Box>
      )}
      {beakerContents.map(chemical => (
        <Flex>
          <Flex.Item>
            <Box key={chemical.name} color="label">
              <AnimatedNumber
                initial={0}
                value={chemical.volume} />
              {" units of "+chemical.name}
            </Box>
          </Flex.Item>
          <Flex.Item>
            <Box
              ml={1}
              style={{
                'position': 'relative',
                'width': '105px',
                'height': '16px',
                'display': 'flex',
                'background-color': '#363636',
                'border': '2px solid #363636',
                'border-index': '0',
                'box-shadow': '4px 4px #000000',
              }}>
              {chemical.pressureProfile.map(phase => (
                !!phase.ratio && (
                  <Box
                    key={chemical.name+phase.name}
                    position="relative"
                    color="#000000"
                    style={{
                      'position': 'absolute',
                      'left': `${offset}px`,
                      'width': `${(phase.ratio*100)}%`,
                      'height': '12px',
                      'background-color': `${(phase.color)}`,
                      'transition': '1.2s ease-out',
                    }}>
                    <Tooltip
                      content={`${(phase.name)}: ${round(phase.ratio*100)}%`} />
                    {incrementOffset(phase.ratio*100)}
                  </Box>
                )
              ))}
              {incrementOffset(-100)}
            </Box>
          </Flex.Item>
        </Flex>
      ))}
    </Box>
  );
};
